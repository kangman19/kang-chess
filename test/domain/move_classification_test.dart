import 'package:flutter_test/flutter_test.dart';
import 'package:kang_chess/src/domain/move_classification.dart';
import 'package:kang_chess/src/domain/score.dart';

MoveClass grade(double best, double after,
        {bool isBest = false,
        double? second,
        bool book = false,
        bool recapture = false,
        int swing = 0,
        double? opponentLoss}) =>
    classifyMove(MoveFacts(
      winBest: best,
      winAfter: after,
      isBestMove: isBest,
      winSecond: second,
      isBook: book,
      isRecapture: recapture,
      materialSwing: swing,
      opponentPreviousLoss: opponentLoss,
    ));

void main() {
  group('win probability', () {
    test('logistic mapping', () {
      expect(const Score.cp(0).winProbability, closeTo(0.5, 1e-9));
      expect(const Score.cp(100).winProbability, closeTo(0.591, 0.001));
      expect(const Score.cp(-300).winProbability, closeTo(0.249, 0.001));
      expect(const Score.mate(3).winProbability, 1.0);
      expect(const Score.mate(-2).winProbability, 0.0);
      expect(Score.mated.winProbability, 0.0);
    });

    test('negate flips perspective', () {
      expect(const Score.cp(120).negate(), const Score.cp(-120));
      expect(const Score.mate(2).negate(), const Score.mate(-2));
    });
  });

  group('threshold classes', () {
    test('expected-points bands', () {
      expect(grade(0.6, 0.6, isBest: true), MoveClass.best);
      expect(grade(0.60, 0.59), MoveClass.excellent);
      expect(grade(0.60, 0.56), MoveClass.good);
      expect(grade(0.60, 0.52), MoveClass.inaccuracy);
      expect(grade(0.60, 0.45), MoveClass.mistake);
      expect(grade(0.60, 0.30), MoveClass.blunder);
    });

    test('best move never loses points even if after-search disagrees', () {
      expect(grade(0.7, 0.6, isBest: true), MoveClass.best);
    });
  });

  group('special classes', () {
    test('book overrides when loss is small', () {
      expect(grade(0.55, 0.54, book: true), MoveClass.book);
      expect(grade(0.55, 0.40, book: true), MoveClass.mistake);
    });

    test('brilliant requires a sound sacrifice when not already winning', () {
      expect(grade(0.7, 0.7, isBest: true, second: 0.5, swing: -3),
          MoveClass.brilliant);
      // Trade, not a sacrifice.
      expect(grade(0.7, 0.7, isBest: true, second: 0.5, swing: 0),
          MoveClass.great);
      // Already completely winning without it.
      expect(grade(0.99, 0.99, isBest: true, second: 0.97, swing: -3),
          MoveClass.best);
      // Unsound: leaves a bad position.
      expect(grade(0.45, 0.45, isBest: true, second: 0.30, swing: -3),
          MoveClass.great);
      // A single pawn is not enough.
      expect(grade(0.7, 0.7, isBest: true, second: 0.6, swing: -1),
          MoveClass.best);
    });

    test('great is the only good move, excluding recaptures', () {
      expect(grade(0.5, 0.5, isBest: true, second: 0.2), MoveClass.great);
      expect(grade(0.5, 0.5, isBest: true, second: 0.2, recapture: true),
          MoveClass.best);
      expect(grade(0.5, 0.5, isBest: true, second: 0.45), MoveClass.best);
    });

    test('miss: failing to punish an opponent error', () {
      expect(grade(0.85, 0.55, opponentLoss: 0.25), MoveClass.miss);
      // Opponent had not erred: ordinary mistake.
      expect(grade(0.85, 0.70, opponentLoss: 0.01), MoveClass.mistake);
      // No real winning chance existed.
      expect(grade(0.60, 0.45, opponentLoss: 0.25), MoveClass.mistake);
    });
  });

  group('accuracy', () {
    test('perfect move is 100, large drops approach 0', () {
      expect(moveAccuracy(0.6, 0.6), closeTo(100, 0.01));
      expect(moveAccuracy(0.6, 0.65), closeTo(100, 0.01));
      expect(moveAccuracy(0.9, 0.1), lessThan(5));
    });

    test('game accuracy blends arithmetic and harmonic means', () {
      expect(gameAccuracy([]), isNull);
      expect(gameAccuracy([80, 80]), closeTo(80, 1e-9));
      final mixed = gameAccuracy([100, 20])!;
      expect(mixed, lessThan(60));
      expect(mixed, greaterThan(33));
    });
  });
}
