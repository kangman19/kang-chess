import 'package:dartchess/dartchess.dart';

import '../core/chess_utils.dart';
import '../core/opening_book.dart';
import '../domain/move_classification.dart';
import '../domain/score.dart';
import '../engine/engine_service.dart';
import '../game/game_controller.dart';

/// Engine verdict on one position, from the side to move's point of view.
class PositionEval {
  const PositionEval({
    required this.score,
    this.bestMove,
    this.line = const [],
    this.second,
  });

  final Score score;

  /// Best move in standard UCI; `null` for terminal positions.
  final String? bestMove;

  /// Principal variation starting with [bestMove].
  final List<String> line;

  /// Score of the second-best move, if there is one.
  final Score? second;
}

/// Graded review of one played move.
class MoveReview {
  const MoveReview({
    required this.ply,
    required this.played,
    required this.classification,
    required this.loss,
    required this.accuracy,
    required this.evalWhite,
    required this.bestMoveUci,
    required this.bestMoveSan,
  });

  /// 1-based ply number.
  final int ply;
  final PlayedMove played;
  final MoveClass classification;

  /// Expected points lost (0..1).
  final double loss;
  final double accuracy;

  /// Evaluation after the move, from White's point of view.
  final Score evalWhite;

  /// Engine's best move in the position before this move.
  final String? bestMoveUci;
  final String? bestMoveSan;
}

/// Runs one search per position of a finished game.
class GameAnalyzer {
  GameAnalyzer(this._engine, {this.depth = 14});

  static const pvPliesForSacrifice = 6;

  final EngineService _engine;
  final int depth;

  /// Evaluates positions 0..n in order, yielding `(index, eval)`.
  Stream<(int, PositionEval)> evaluate(
    List<PlayedMove> moves, {
    GameResult? result,
    required CancelToken cancel,
  }) async* {
    var position = Chess.initial as Position;
    final ucis = [for (final m in moves) m.uci];
    for (var i = 0; i <= moves.length; i++) {
      if (cancel.isCancelled) return;
      if (i > 0) position = position.play(moves[i - 1].move);
      final terminal = _terminalEval(position, i == moves.length ? result : null);
      if (terminal != null) {
        yield (i, terminal);
        continue;
      }
      final search = await _engine.search(
        SearchRequest(
          startFen: GameController.startFen,
          moves: ucis.sublist(0, i),
          options: const EngineOptions(multiPv: 2),
          depth: depth,
        ),
        cancel: cancel,
      );
      final best = search.best;
      if (cancel.isCancelled || best == null) return;
      yield (
        i,
        PositionEval(
          score: best.score,
          bestMove: search.bestMove ?? best.firstMove,
          line: best.moves,
          second: search.second?.score,
        ),
      );
    }
  }

  static PositionEval? _terminalEval(Position pos, GameResult? result) {
    if (pos.isCheckmate) return const PositionEval(score: Score.mated);
    if (pos.isStalemate || pos.isInsufficientMaterial) {
      return const PositionEval(score: Score.draw);
    }
    final reason = result?.reason;
    if (reason == GameEndReason.threefold || reason == GameEndReason.fiftyMove) {
      return const PositionEval(score: Score.draw);
    }
    return null;
  }
}

/// Grades [played] from the evaluations before and after it.
///
/// [history] holds every move up to and including [played], standard UCI.
MoveReview reviewMove({
  required int ply,
  required Position before,
  required PlayedMove played,
  required PositionEval evalBefore,
  required PositionEval evalAfter,
  required List<String> history,
  PlayedMove? previous,
  double? previousLoss,
}) {
  final mover = before.turn;
  final winBest = evalBefore.score.winProbability;
  final scoreAfter = evalAfter.score.negate();
  final isRecapture = previous != null &&
      previous.captured &&
      played.captured &&
      played.move.to == previous.move.to;

  final facts = MoveFacts(
    winBest: winBest,
    winAfter: scoreAfter.winProbability,
    winSecond: evalBefore.second?.winProbability,
    isBestMove: played.uci == evalBefore.bestMove,
    isBook: OpeningBook.contains(history),
    isRecapture: isRecapture,
    materialSwing: _materialSwing(before, played.move, evalAfter.line),
    opponentPreviousLoss: previousLoss,
  );

  final bestUci = evalBefore.bestMove;
  final bestMove = bestUci == null ? null : parseLegalUci(before, bestUci);

  return MoveReview(
    ply: ply,
    played: played,
    classification: classifyMove(facts),
    loss: facts.loss,
    accuracy:
        facts.isBestMove ? 100 : moveAccuracy(facts.winBest, facts.winAfter),
    evalWhite: mover == Side.white ? scoreAfter : evalAfter.score,
    bestMoveUci: bestUci,
    bestMoveSan: bestMove == null ? null : before.makeSan(bestMove).$2,
  );
}

/// Mover's material change after [move] and the engine's reply line.
int _materialSwing(Position before, NormalMove move, List<String> replyLine) {
  final mover = before.turn;
  final start = materialBalance(before.board, mover);
  var pos = before.play(move);
  for (final uci in replyLine.take(GameAnalyzer.pvPliesForSacrifice)) {
    final next = parseLegalUci(pos, uci);
    if (next == null) break;
    pos = pos.play(next);
  }
  return materialBalance(pos.board, mover) - start;
}
