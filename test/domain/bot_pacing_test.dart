import 'dart:math' as math;

import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kang_chess/src/domain/bot_pacing.dart';
import 'package:kang_chess/src/domain/bot_profile.dart';

BotProfile bot(String id) => BotProfile.all.firstWhere((b) => b.id == id);

// Italian Game after 4...Bc5 5.Nc3: a normal middlegame-ish position.
final middlegame = Chess.fromSetup(Setup.parseFen(
    'r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/2N2N2/PPPP1PPP/R1BQK2R b KQkq - 4 5'));

void main() {
  List<double> sample(BotProfile b,
      {Position? position, int ply = 30, Duration? remaining, int n = 400}) {
    final pacer = BotPacer(random: math.Random(7));
    return [
      for (var i = 0; i < n; i++)
        pacer
                .thinkTime(
                  bot: b,
                  position: position ?? middlegame,
                  ply: ply,
                  remaining: remaining,
                )
                .inMilliseconds /
            1000,
    ];
  }

  double median(List<double> xs) => (List.of(xs)..sort())[xs.length ~/ 2];

  test('stronger bots think longer than weaker ones', () {
    expect(median(sample(bot('ivo'))), greaterThan(median(sample(bot('pebble'))) * 2));
  });

  test('think times vary from move to move', () {
    final times = sample(bot('june'));
    expect(times.toSet().length, greaterThan(300));
    expect(times.reduce(math.max), greaterThan(median(times) * 2));
  });

  test('opening moves are quicker than middlegame moves', () {
    expect(median(sample(bot('kwame'), ply: 2)),
        lessThan(median(sample(bot('kwame'))) * 0.5));
  });

  test('forced moves are played almost immediately', () {
    // Black king in check from a rook with a single escape square.
    final forced = Chess.fromSetup(Setup.parseFen('k7/8/1K6/8/8/8/8/R7 b - - 0 1'));
    expect(sample(bot('ivo'), position: forced).reduce(math.max), lessThan(1));
  });

  test('never spends more than a slice of a low clock', () {
    final times = sample(bot('grandmaster'), remaining: const Duration(seconds: 10));
    expect(times.reduce(math.max), lessThanOrEqualTo(1.2));
  });

  test('instant pacer adds no delay', () {
    expect(
      BotPacer.instant().thinkTime(bot: bot('ivo'), position: middlegame, ply: 30),
      Duration.zero,
    );
  });
}
