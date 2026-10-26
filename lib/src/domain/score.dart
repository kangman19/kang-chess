import 'dart:math' as math;

/// Engine evaluation from the side-to-move's point of view.
///
/// Exactly one of [cp] or [mate] is set. `mate == 0` means the side to move
/// is checkmated.
class Score {
  const Score.cp(int this.cp) : mate = null;
  const Score.mate(int this.mate) : cp = null;

  static const draw = Score.cp(0);
  static const mated = Score.mate(0);

  final int? cp;
  final int? mate;

  bool get isMate => mate != null;

  Score negate() => mate != null ? Score.mate(-mate!) : Score.cp(-cp!);

  /// Win probability (expected points, 0..1) for the side to move.
  double get winProbability {
    final m = mate;
    if (m != null) return m > 0 ? 1.0 : 0.0;
    return 1 / (1 + math.exp(-0.00368208 * cp!));
  }

  /// A single comparable number in centipawns; mates map far beyond any
  /// material score, with shorter mates ranked higher.
  int get sortValue {
    final m = mate;
    if (m == null) return cp!;
    if (m > 0) return 100000 - m * 10;
    return -100000 - m * 10;
  }

  /// Short display text, e.g. "+1.3", "-0.4", "M3", "-M2".
  String get display {
    final m = mate;
    if (m != null) return m > 0 ? 'M$m' : (m == 0 ? '#' : '-M${-m}');
    final pawns = cp! / 100;
    return '${pawns >= 0 ? '+' : ''}${pawns.toStringAsFixed(1)}';
  }

  @override
  bool operator ==(Object other) =>
      other is Score && other.cp == cp && other.mate == mate;

  @override
  int get hashCode => Object.hash(cp, mate);

  @override
  String toString() => mate != null ? 'mate $mate' : 'cp $cp';
}
