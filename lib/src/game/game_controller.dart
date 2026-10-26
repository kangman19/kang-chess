import 'dart:async';
import 'dart:math' as math;

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';

import '../core/chess_utils.dart';
import '../domain/bot_profile.dart';
import '../domain/chess_clock.dart';
import '../domain/premove_queue.dart';
import '../domain/time_control.dart';
import '../engine/bot_move_picker.dart';
import '../engine/engine_service.dart';

enum GameEndReason {
  checkmate('Checkmate'),
  stalemate('Stalemate'),
  insufficientMaterial('Insufficient material'),
  threefold('Threefold repetition'),
  fiftyMove('50-move rule'),
  timeout('Time out'),
  timeoutVsInsufficient('Time out vs insufficient material'),
  resignation('Resignation');

  const GameEndReason(this.label);
  final String label;
}

class GameResult {
  const GameResult(this.winner, this.reason);

  /// `null` for a draw.
  final Side? winner;
  final GameEndReason reason;

  String get score => switch (winner) {
        Side.white => '1-0',
        Side.black => '0-1',
        null => '½-½',
      };
}

/// A move as recorded in the game history.
class PlayedMove {
  const PlayedMove({
    required this.move,
    required this.san,
    required this.uci,
    required this.fenAfter,
    required this.mover,
    required this.captured,
  });

  /// dartchess form (castling as king-takes-rook).
  final NormalMove move;
  final String san;

  /// Standard UCI (castling as king two squares).
  final String uci;
  final String fenAfter;
  final Side mover;
  final bool captured;
}

/// Owns one game against a bot: rules, clocks, premoves, and bot turns.
///
/// Bot results are tagged with a generation number; anything that arrives
/// after the game ended or the controller was disposed is dropped.
class GameController extends ChangeNotifier {
  GameController({
    required this.bot,
    required this.playerSide,
    required this.clockSetup,
    required EngineService engine,
    this.premovesEnabled = true,
    math.Random? random,
  })  : _random = random ?? math.Random(),
        _picker = BotMovePicker(engine, random: random) {
    clock = ChessClock(clockSetup, onFlag: _onFlag);
    _repetitions[_position.zobristHash()] = 1;
  }

  static const startFen = kInitialFEN;

  final BotProfile bot;
  final Side playerSide;
  final ClockSetup clockSetup;
  final bool premovesEnabled;
  final math.Random _random;
  final BotMovePicker _picker;
  late final ChessClock clock;

  final PremoveQueue _premoves = PremoveQueue();
  final List<PlayedMove> _moves = [];
  final Map<int, int> _repetitions = {};
  Position _position = Chess.initial;
  GameResult? _result;
  bool _botThinking = false;
  int _generation = 0;
  CancelToken? _botCancel;
  Completer<void>? _humanDelay;
  int _premoveCancellations = 0;
  String? _engineError;
  bool _disposed = false;

  Position get position => _position;
  List<PlayedMove> get moves => List.unmodifiable(_moves);
  GameResult? get result => _result;
  bool get isOver => _result != null;
  bool get botThinking => _botThinking;
  Side get botSide => playerSide.opposite;
  bool get isPlayerTurn => !isOver && _position.turn == playerSide;
  List<NormalMove> get premoves => _premoves.moves;

  /// Increments whenever a queued premove was cancelled as illegal.
  int get premoveCancellations => _premoveCancellations;

  /// Set when the engine failed and the bot fell back to a random move.
  String? get engineError => _engineError;

  /// Board to draw: the real position with queued premoves applied.
  Board get displayBoard => _premoves.project(_position.board);

  PlayedMove? get lastMove => _moves.isEmpty ? null : _moves.last;

  /// Begins the game; the bot moves first if it has White.
  void start() {
    if (_position.turn == botSide) unawaited(_botTurn());
  }

  /// Handles a move made on the board by the player.
  ///
  /// Plays it if it is the player's turn, otherwise queues it as a premove.
  /// Returns whether the move was accepted.
  bool playerMove(NormalMove move) {
    if (isOver) return false;
    if (isPlayerTurn) {
      final legal = legalOrNull(_position, move);
      if (legal == null) return false;
      _apply(legal);
      if (!isOver) unawaited(_botTurn());
      notifyListeners();
      return true;
    }
    if (!premovesEnabled) return false;
    final added = _premoves.add(_position.board, playerSide, move);
    if (added) notifyListeners();
    return added;
  }

  void clearPremoves() {
    if (_premoves.isEmpty) return;
    _premoves.clear();
    notifyListeners();
  }

  void resign() {
    if (isOver) return;
    _finish(GameResult(botSide, GameEndReason.resignation));
  }

  void _apply(NormalMove move) {
    final mover = _position.turn;
    final uci = toStandardUci(_position, move);
    final captured = isCapture(_position, move);
    final (next, san) = _position.makeSan(move);
    // A move completed after flag fall does not count.
    clock.moveMade(mover);
    if (isOver) return;
    _position = next;
    _moves.add(PlayedMove(
      move: move,
      san: san,
      uci: uci,
      fenAfter: next.fen,
      mover: mover,
      captured: captured,
    ));
    final hash = next.zobristHash();
    _repetitions[hash] = (_repetitions[hash] ?? 0) + 1;
    _checkEnd(_repetitions[hash]!);
  }

  void _checkEnd(int repetitionCount) {
    final pos = _position;
    if (pos.isCheckmate) {
      _finish(GameResult(pos.turn.opposite, GameEndReason.checkmate));
    } else if (pos.isStalemate) {
      _finish(const GameResult(null, GameEndReason.stalemate));
    } else if (pos.isInsufficientMaterial) {
      _finish(const GameResult(null, GameEndReason.insufficientMaterial));
    } else if (repetitionCount >= 3) {
      _finish(const GameResult(null, GameEndReason.threefold));
    } else if (pos.halfmoves >= 100) {
      _finish(const GameResult(null, GameEndReason.fiftyMove));
    }
  }

  void _onFlag(Side flagged) {
    if (isOver) return;
    final opponent = flagged.opposite;
    _finish(_position.hasInsufficientMaterial(opponent)
        ? const GameResult(null, GameEndReason.timeoutVsInsufficient)
        : GameResult(opponent, GameEndReason.timeout));
  }

  void _finish(GameResult result) {
    _result = result;
    _generation++;
    _botThinking = false;
    _botCancel?.cancel();
    _releaseDelay();
    _premoves.clear();
    clock.stop();
    if (!_disposed) notifyListeners();
  }

  Future<void> _botTurn() async {
    final generation = ++_generation;
    _botThinking = true;
    notifyListeners();

    if (bot.humanizedDelay) {
      final delay = Duration(milliseconds: 300 + _random.nextInt(600));
      final waited = _humanDelay = Completer<void>();
      final timer = Timer(delay, () {
        if (!waited.isCompleted) waited.complete();
      });
      await waited.future;
      timer.cancel();
      if (generation != _generation) return;
    }

    final cancel = _botCancel = CancelToken();
    NormalMove? move;
    try {
      move = await _picker.pickMove(
        bot: bot,
        position: _position,
        startFen: startFen,
        history: [for (final m in _moves) m.uci],
        remaining: clock.isTimed ? clock.remaining(botSide) : null,
        increment: clockSetup.of(botSide)?.increment ?? Duration.zero,
        cancel: cancel,
      );
    } catch (error) {
      _engineError = '$error';
      final legal = allLegalMoves(_position);
      move = legal.isEmpty ? null : legal[_random.nextInt(legal.length)];
    }
    if (generation != _generation || _disposed || move == null) return;

    _botThinking = false;
    _apply(move);
    if (!isOver) _playPremove();
    notifyListeners();
  }

  /// Runs the head premove right after the bot's move (0 ms clock cost).
  void _playPremove() {
    if (_premoves.isEmpty) return;
    final next = _premoves.takeLegal(_position);
    if (next == null) {
      _premoveCancellations++;
      return;
    }
    _apply(next);
    if (!isOver) unawaited(_botTurn());
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _botCancel?.cancel();
    _releaseDelay();
    clock.dispose();
    super.dispose();
  }

  /// Wakes a pending humanizing delay so its bot turn can observe the new
  /// generation and exit.
  void _releaseDelay() {
    final delay = _humanDelay;
    if (delay != null && !delay.isCompleted) delay.complete();
    _humanDelay = null;
  }
}
