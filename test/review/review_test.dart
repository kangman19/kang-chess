import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kang_chess/src/core/chess_utils.dart';
import 'package:kang_chess/src/domain/move_classification.dart';
import 'package:kang_chess/src/domain/score.dart';
import 'package:kang_chess/src/engine/engine_service.dart';
import 'package:kang_chess/src/game/game_controller.dart';
import 'package:kang_chess/src/review/game_analyzer.dart';
import 'package:kang_chess/src/review/review_controller.dart';

import '../support/fake_uci.dart';

List<PlayedMove> playOut(List<String> ucis) {
  var pos = Chess.initial as Position;
  final played = <PlayedMove>[];
  for (final uci in ucis) {
    final move = parseLegalUci(pos, uci)!;
    final captured = isCapture(pos, move);
    final (next, san) = pos.makeSan(move);
    played.add(PlayedMove(
      move: move,
      san: san,
      uci: toStandardUci(pos, move),
      fenAfter: next.fen,
      mover: pos.turn,
      captured: captured,
    ));
    pos = next;
  }
  return played;
}

void main() {
  test('a sound piece sacrifice is graded Brilliant', () {
    final before = Chess.fromSetup(
        Setup.parseFen('4k3/8/3p4/8/8/5N2/8/4K3 w - - 0 1'));
    final move = NormalMove.fromUci('f3e5');
    final (after, san) = before.makeSan(move);
    final played = PlayedMove(
      move: move, san: san, uci: 'f3e5', fenAfter: after.fen,
      mover: Side.white, captured: false,
    );
    final review = reviewMove(
      ply: 1,
      before: before,
      played: played,
      evalBefore: const PositionEval(
          score: Score.cp(300), bestMove: 'f3e5', second: Score.cp(0)),
      // Black to move; engine expects d6xe5 and still evaluates -3 for Black.
      evalAfter: const PositionEval(
          score: Score.cp(-300), bestMove: 'd6e5', line: ['d6e5']),
      history: const ['f3e5'],
    );
    expect(review.classification, MoveClass.brilliant);
    expect(review.evalWhite, const Score.cp(300));
    expect(review.accuracy, 100);
  });

  test('a dropped piece is graded Blunder with the best move named', () {
    final before = Chess.fromSetup(
        Setup.parseFen('4k3/8/3p4/8/8/5N2/8/4K3 w - - 0 1'));
    final move = NormalMove.fromUci('f3e5');
    final (after, san) = before.makeSan(move);
    final review = reviewMove(
      ply: 1,
      before: before,
      played: PlayedMove(
        move: move, san: san, uci: 'f3e5', fenAfter: after.fen,
        mover: Side.white, captured: false,
      ),
      evalBefore: const PositionEval(score: Score.cp(250), bestMove: 'f3d4'),
      evalAfter: const PositionEval(
          score: Score.cp(150), bestMove: 'd6e5', line: ['d6e5']),
      history: const ['f3e5'],
    );
    expect(review.classification, MoveClass.blunder);
    expect(review.bestMoveSan, 'Nd4');
    expect(review.loss, greaterThan(0.2));
  });

  test('review controller grades every move and skips search on mate',
      () async {
    final transport = FakeUciTransport();
    final engine = EngineService(transport);
    final moves = playOut(['f2f3', 'e7e5', 'g2g4', 'd8h4']);
    final review = ReviewController(
      moves: moves,
      result: const GameResult(Side.black, GameEndReason.checkmate),
      playerSide: Side.white,
      engine: engine,
      depth: 8,
    )..start();
    while (!review.isFinished) {
      await pumpEventQueue();
    }
    expect(review.error, isNull);
    expect(review.reviews, hasLength(4));
    expect(review.progress, 1);
    // Positions 0..3 searched; the mate position is terminal.
    expect(transport.goCount, 4);
    expect(review.reviewAt(4)!.evalWhite.winProbability, 0.0);
    expect(review.accuracy(Side.white), isNotNull);
    expect(review.counts(Side.black).values.reduce((a, b) => a + b), 2);
    review.dispose();
    await engine.dispose();
  });

  test('disposing the review cancels outstanding analysis', () async {
    final transport = FakeUciTransport(holdSearches: true);
    final engine = EngineService(transport);
    final review = ReviewController(
      moves: playOut(['e2e4', 'e7e5', 'g1f3']),
      result: null,
      playerSide: Side.white,
      engine: engine,
    )..start();
    await pumpEventQueue();
    expect(transport.goCount, 1);
    review.dispose();
    await pumpEventQueue();
    expect(transport.sent.last, 'stop');
    await pumpEventQueue();
    expect(transport.goCount, 1);
    await engine.dispose();
  });
}
