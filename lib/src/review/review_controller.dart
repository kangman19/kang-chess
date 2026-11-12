import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';

import '../domain/move_classification.dart';
import '../domain/score.dart';
import '../engine/engine_service.dart';
import '../game/game_controller.dart';
import 'game_analyzer.dart';

/// Runs and holds a post-game review. Results appear move by move.
class ReviewController extends ChangeNotifier {
  ReviewController({
    required List<PlayedMove> moves,
    required this.result,
    required this.playerSide,
    required EngineService engine,
    int depth = 14,
  })  : moves = List.unmodifiable(moves),
        _analyzer = GameAnalyzer(engine, depth: depth) {
    var pos = Chess.initial as Position;
    _positions.add(pos);
    for (final m in moves) {
      pos = pos.play(m.move);
      _positions.add(pos);
    }
    _evals = List.filled(moves.length + 1, null);
  }

  final List<PlayedMove> moves;
  final GameResult? result;
  final Side playerSide;
  final GameAnalyzer _analyzer;
  final List<Position> _positions = [];
  late final List<PositionEval?> _evals;
  final List<MoveReview> _reviews = [];
  final CancelToken _cancel = CancelToken();
  StreamSubscription<(int, PositionEval)>? _subscription;

  int _selectedPly = 0;
  bool _finished = false;
  Object? _error;

  /// 0 is the starting position; `n` is after move `n`.
  int get selectedPly => _selectedPly;
  int get plyCount => moves.length;
  bool get isFinished => _finished;
  Object? get error => _error;
  List<MoveReview> get reviews => List.unmodifiable(_reviews);
  double get progress =>
      _evals.isEmpty ? 1 : _evals.where((e) => e != null).length / _evals.length;

  Position positionAt(int ply) => _positions[ply];
  PositionEval? evalAt(int ply) => _evals[ply];
  MoveReview? reviewAt(int ply) =>
      ply >= 1 && ply <= _reviews.length ? _reviews[ply - 1] : null;

  /// Evaluation of the selected position from White's point of view.
  Score? get selectedEvalWhite {
    final eval = _evals[_selectedPly];
    if (eval == null) return null;
    return _positions[_selectedPly].turn == Side.white
        ? eval.score
        : eval.score.negate();
  }

  double? accuracy(Side side) =>
      gameAccuracy(_reviews.where((r) => r.played.mover == side).map((r) => r.accuracy));

  Map<MoveClass, int> counts(Side side) {
    final counts = {for (final c in MoveClass.values) c: 0};
    for (final r in _reviews.where((r) => r.played.mover == side)) {
      counts[r.classification] = counts[r.classification]! + 1;
    }
    return counts;
  }

  void start() {
    if (_subscription != null) return;
    _subscription = _analyzer
        .evaluate(moves, result: result, cancel: _cancel)
        .listen(_onEval, onError: (Object e) {
      _error = e;
      _finished = true;
      notifyListeners();
    }, onDone: () {
      _finished = true;
      notifyListeners();
    });
  }

  void _onEval((int, PositionEval) event) {
    final (index, eval) = event;
    _evals[index] = eval;
    if (index >= 1) {
      final previous = _reviews.isEmpty ? null : _reviews.last;
      _reviews.add(reviewMove(
        ply: index,
        before: _positions[index - 1],
        played: moves[index - 1],
        evalBefore: _evals[index - 1]!,
        evalAfter: eval,
        history: [for (final m in moves.take(index)) m.uci],
        previous: index >= 2 ? moves[index - 2] : null,
        previousLoss: previous?.loss,
      ));
    }
    notifyListeners();
  }

  static const _quietClasses = {
    MoveClass.best,
    MoveClass.excellent,
    MoveClass.good,
    MoveClass.book,
  };

  bool isKeyMove(int ply) {
    final r = reviewAt(ply);
    return r != null && !_quietClasses.contains(r.classification);
  }

  /// Nearest key move before the selection, or null if there is none.
  int? get previousKeyMove {
    for (var p = _selectedPly - 1; p >= 1; p--) {
      if (isKeyMove(p)) return p;
    }
    return null;
  }

  /// Nearest key move after the selection, or null if there is none.
  int? get nextKeyMove {
    for (var p = _selectedPly + 1; p <= _reviews.length; p++) {
      if (isKeyMove(p)) return p;
    }
    return null;
  }

  void select(int ply) {
    final clamped = ply.clamp(0, plyCount);
    if (clamped == _selectedPly) return;
    _selectedPly = clamped;
    notifyListeners();
  }

  @override
  void dispose() {
    _cancel.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
