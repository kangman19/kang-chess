import 'dart:math' as math;

/// Review grades, best first. See ANALYSIS.md §1 for the rules.
enum MoveClass {
  brilliant('Brilliant', '!!'),
  great('Great', '!'),
  best('Best', '★'),
  excellent('Excellent', '👍'),
  good('Good', '✓'),
  book('Book', '📖'),
  inaccuracy('Inaccuracy', '?!'),
  mistake('Mistake', '?'),
  miss('Miss', 'X'),
  blunder('Blunder', '??');

  const MoveClass(this.label, this.symbol);

  final String label;
  final String symbol;
}

/// Expected-points thresholds (Chess.com Help Center ranges).
const double excellentMaxLoss = 0.02;
const double goodMaxLoss = 0.05;
const double inaccuracyMaxLoss = 0.10;
const double mistakeMaxLoss = 0.20;

/// Our special-class parameters (ANALYSIS.md §1.4).
const double bookMaxLoss = 0.05;
const int brilliantMinSacrifice = 2;
const double brilliantMinWinAfter = 0.50;
const double brilliantMaxWinWithoutSac = 0.95;
const double greatMinGap = 0.15;
const double missMinOpponentLoss = 0.10;
const double missMinWinChance = 0.70;

/// Engine facts about one played move, all from the mover's point of view.
class MoveFacts {
  const MoveFacts({
    required this.winBest,
    required this.winAfter,
    required this.isBestMove,
    this.winSecond,
    this.isBook = false,
    this.isRecapture = false,
    this.materialSwing = 0,
    this.opponentPreviousLoss,
  });

  /// Win probability of the best line before the move.
  final double winBest;

  /// Win probability after the played move.
  final double winAfter;

  /// Win probability of the second-best line, if the engine reported one.
  final double? winSecond;

  final bool isBestMove;
  final bool isBook;

  /// Captures back on the square where the opponent just captured.
  final bool isRecapture;

  /// Mover's material balance change after the move plus the engine's reply
  /// line (negative means material was given up).
  final int materialSwing;

  /// Expected points the opponent lost on their previous move.
  final double? opponentPreviousLoss;

  /// Expected points lost relative to the best move.
  double get loss => isBestMove ? 0 : math.max(0, winBest - winAfter);
}

MoveClass classifyMove(MoveFacts f) {
  final loss = f.loss;

  if (f.isBook && loss <= bookMaxLoss) return MoveClass.book;

  final second = f.winSecond;
  if (loss <= excellentMaxLoss &&
      f.materialSwing <= -brilliantMinSacrifice &&
      f.winAfter >= brilliantMinWinAfter &&
      second != null &&
      second < brilliantMaxWinWithoutSac) {
    return MoveClass.brilliant;
  }

  if (f.isBestMove &&
      second != null &&
      f.winBest - second >= greatMinGap &&
      !f.isRecapture) {
    return MoveClass.great;
  }

  final opponentLoss = f.opponentPreviousLoss;
  if (opponentLoss != null &&
      opponentLoss >= missMinOpponentLoss &&
      f.winBest >= missMinWinChance &&
      loss >= inaccuracyMaxLoss) {
    return MoveClass.miss;
  }

  if (f.isBestMove) return MoveClass.best;
  if (loss <= excellentMaxLoss) return MoveClass.excellent;
  if (loss <= goodMaxLoss) return MoveClass.good;
  if (loss <= inaccuracyMaxLoss) return MoveClass.inaccuracy;
  if (loss <= mistakeMaxLoss) return MoveClass.mistake;
  return MoveClass.blunder;
}

/// Per-move accuracy (0..100) from win probabilities in 0..1.
double moveAccuracy(double winBefore, double winAfter) {
  final drop = math.max(0.0, (winBefore - winAfter) * 100);
  final raw = 103.1668 * math.exp(-0.04354 * drop) - 3.1669;
  return raw.clamp(0.0, 100.0);
}

/// Game accuracy: average of arithmetic and harmonic means of move accuracy.
double? gameAccuracy(Iterable<double> accuracies) {
  final values = accuracies.toList();
  if (values.isEmpty) return null;
  final arithmetic = values.reduce((a, b) => a + b) / values.length;
  // Floor at 1 so a single 0 does not collapse the harmonic mean.
  final harmonic =
      values.length / values.map((v) => 1 / math.max(v, 1.0)).reduce((a, b) => a + b);
  return (arithmetic + harmonic) / 2;
}
