import 'dart:math' as math;

import 'package:dartchess/dartchess.dart';

import '../core/chess_utils.dart';
import '../domain/bot_profile.dart';
import 'engine_service.dart';

/// Chooses bot moves according to a [BotProfile]. See ANALYSIS.md §2.2.
class BotMovePicker {
  BotMovePicker(this._engine, {math.Random? random})
      : _random = random ?? math.Random();

  final EngineService _engine;
  final math.Random _random;

  /// Picks a move for the side to move in [position].
  ///
  /// [startFen] and [history] (standard UCI) describe how [position] was
  /// reached. Returns `null` if [cancel] fired.
  Future<NormalMove?> pickMove({
    required BotProfile bot,
    required Position position,
    required String startFen,
    required List<String> history,
    Duration? remaining,
    Duration increment = Duration.zero,
    CancelToken? cancel,
  }) async {
    final legal = allLegalMoves(position);
    if (legal.isEmpty) return null;

    if (bot.randomMoveRate > 0 && _random.nextDouble() < bot.randomMoveRate) {
      return legal[_random.nextInt(legal.length)];
    }

    final result = await _engine.search(
      SearchRequest(
        startFen: startFen,
        moves: history,
        options: EngineOptions(
          multiPv: bot.usesInjection ? bot.multiPv : 1,
          limitElo: bot.uciElo,
        ),
        depth: bot.depth,
        movetime: thinkTime(bot, remaining, increment),
      ),
      cancel: cancel,
    );
    if (cancel?.isCancelled ?? false) return null;

    if (bot.usesInjection && result.lines.isNotEmpty) {
      final candidates = <NormalMove>[];
      final scores = <double>[];
      for (final line in result.lines) {
        final uci = line.firstMove;
        final move = uci == null ? null : parseLegalUci(position, uci);
        if (move == null) continue;
        candidates.add(move);
        scores.add(line.score.sortValue + styleBonus(bot.style, position, move));
      }
      if (candidates.isNotEmpty) {
        return candidates[sampleSoftmax(scores, bot.temperature, _random)];
      }
    }

    final best = result.bestMove;
    final move = best == null ? null : parseLegalUci(position, best);
    return move ?? legal[_random.nextInt(legal.length)];
  }

  /// Search time: the profile cap, reduced to fit the bot's clock.
  static Duration thinkTime(
      BotProfile bot, Duration? remaining, Duration increment) {
    var time = bot.movetimeCap;
    if (remaining != null) {
      final budget = remaining ~/ 30 + increment ~/ 2;
      if (budget < time) time = budget;
    }
    const floor = Duration(milliseconds: 50);
    return time < floor ? floor : time;
  }
}

/// Centipawn bonus a style adds to a candidate before sampling.
double styleBonus(BotStyle style, Position position, NormalMove move) {
  switch (style) {
    case BotStyle.balanced:
      return 0;
    case BotStyle.chaotic:
      return 0;
    case BotStyle.aggressive:
      var bonus = 0.0;
      if (isCapture(position, move)) bonus += 40;
      if (position.play(move).isCheck) bonus += 60;
      return bonus;
    case BotStyle.solid:
      return isCapture(position, move) || position.play(move).isCheck ? 0 : 25;
  }
}

/// Samples an index with probability ∝ exp((score − max) / temperature).
int sampleSoftmax(List<double> scores, double temperature, math.Random random) {
  assert(scores.isNotEmpty);
  if (temperature <= 0 || scores.length == 1) {
    var bestIndex = 0;
    for (var i = 1; i < scores.length; i++) {
      if (scores[i] > scores[bestIndex]) bestIndex = i;
    }
    return bestIndex;
  }
  final top = scores.reduce(math.max);
  final weights = [for (final s in scores) math.exp((s - top) / temperature)];
  final total = weights.reduce((a, b) => a + b);
  var pick = random.nextDouble() * total;
  for (var i = 0; i < weights.length; i++) {
    pick -= weights[i];
    if (pick <= 0) return i;
  }
  return weights.length - 1;
}
