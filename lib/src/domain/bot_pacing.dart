import 'dart:math' as math;

import 'package:dartchess/dartchess.dart';

import 'bot_profile.dart';

/// How long a bot takes to reply, so it plays at the pace of a person of
/// its rating instead of an instant engine. See ANALYSIS.md §2.3.
///
/// The result is the total wall time from the player's move to the bot's
/// reply; engine search time counts toward it.
class BotPacer {
  BotPacer({math.Random? random})
      : _random = random ?? math.Random(),
        _instant = false;

  /// Replies as soon as the engine does. Used by tests.
  BotPacer.instant()
      : _random = math.Random(0),
        _instant = true;

  final math.Random _random;
  final bool _instant;

  /// Think time for [bot] playing [move] in [position] at half-move [ply].
  ///
  /// [recapture] is set when [move] takes back on the square the opponent
  /// just captured on. [remaining] is the bot's clock, `null` if untimed.
  Duration thinkTime({
    required BotProfile bot,
    required Position position,
    required int ply,
    bool recapture = false,
    Duration? remaining,
    Duration increment = Duration.zero,
  }) {
    if (_instant) return Duration.zero;

    final options =
        position.legalMoves.values.fold(0, (n, dests) => n + dests.size);
    if (options <= 1) return _seconds(0.35 + _random.nextDouble() * 0.5);

    // Typical unhurried think at this rating: 1 s at 100 up to 4.5 s at 2850.
    final skill = ((bot.elo.clamp(100, 2850) - 100) / 2750).toDouble();
    var seconds = 1.0 + 3.5 * skill;

    // Scale toward the bot's per-move budget on the clock.
    final clock = remaining == null ? null : _inSeconds(remaining);
    if (clock != null) {
      final budget = clock / 35 + _inSeconds(increment) * 0.8;
      seconds *= (budget / 5).clamp(0.3, 2.0);
    }

    // Opening moves come from memory; stronger players know more of them.
    final bookPlies = 4 + bot.elo.clamp(0, 2850) ~/ 250;
    if (ply < bookPlies) seconds *= 0.35;

    // Obvious replies are quick; busy positions take longer.
    if (recapture) {
      seconds *= 0.4;
    } else if (position.isCheck && options <= 3) {
      seconds *= 0.5;
    } else {
      seconds *= (0.6 + options / 50).clamp(0.6, 1.4);
    }

    // Log-normal spread, wider for impulsive weaker players, plus the
    // occasional long think.
    seconds *= math.exp((0.6 - 0.2 * skill) * _gaussian());
    if (_random.nextDouble() < 0.07) {
      seconds *= 1.8 + _random.nextDouble() * 1.5;
    }

    // Never spend more than a slice of the clock.
    var cap = 15.0;
    if (clock != null) cap = math.min(cap, clock * 0.12);
    return _seconds(seconds.clamp(math.min(0.35, cap), cap));
  }

  /// Standard normal sample (Box–Muller).
  double _gaussian() {
    final u = 1 - _random.nextDouble();
    final v = _random.nextDouble();
    return math.sqrt(-2 * math.log(u)) * math.cos(2 * math.pi * v);
  }

  static double _inSeconds(Duration d) => d.inMicroseconds / 1e6;

  static Duration _seconds(double s) =>
      Duration(microseconds: (s * 1e6).round());
}
