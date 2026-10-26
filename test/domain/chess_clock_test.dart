import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kang_chess/src/domain/chess_clock.dart';
import 'package:kang_chess/src/domain/time_control.dart';

void main() {
  late Duration now;
  Duration fakeNow() => now;

  setUp(() => now = Duration.zero);

  ChessClock makeClock(ClockSetup setup, {void Function(Side)? onFlag}) =>
      ChessClock(setup, now: fakeNow, autoTick: false, onFlag: onFlag);

  test('charges elapsed time and adds increment after each move', () {
    final clock = makeClock(const ClockSetup.symmetric(
        TimeControl(Duration(minutes: 3), Duration(seconds: 2))));
    clock.moveMade(Side.white); // White's first move is free.
    expect(clock.remaining(Side.white), const Duration(minutes: 3, seconds: 2));
    expect(clock.running, Side.black);

    now += const Duration(seconds: 10);
    expect(clock.remaining(Side.black), const Duration(minutes: 2, seconds: 50));
    clock.moveMade(Side.black);
    expect(clock.remaining(Side.black), const Duration(minutes: 2, seconds: 52));
    expect(clock.running, Side.white);
    clock.dispose();
  });

  test('supports asymmetric controls per side', () {
    final setup = ClockSetup.forPlayer(
      playerSide: Side.black,
      player: const TimeControl(Duration(minutes: 5), Duration(seconds: 2)),
      bot: const TimeControl(Duration(minutes: 1)),
    );
    final clock = makeClock(setup);
    expect(clock.remaining(Side.white), const Duration(minutes: 1));
    expect(clock.remaining(Side.black), const Duration(minutes: 5));
    clock.moveMade(Side.white);
    expect(clock.remaining(Side.white), const Duration(minutes: 1));
    now += const Duration(seconds: 3);
    clock.moveMade(Side.black);
    expect(clock.remaining(Side.black), const Duration(minutes: 4, seconds: 59));
    clock.dispose();
  });

  test('flags on tick when time runs out and stops', () {
    Side? flagged;
    final clock = makeClock(
      const ClockSetup.symmetric(TimeControl(Duration(seconds: 5))),
      onFlag: (s) => flagged = s,
    );
    clock.moveMade(Side.white);
    now += const Duration(seconds: 6);
    clock.tick();
    expect(flagged, Side.black);
    expect(clock.flagged, Side.black);
    expect(clock.running, isNull);
    expect(clock.remaining(Side.black), Duration.zero);
    // Further moves are ignored after a flag.
    clock.moveMade(Side.black);
    expect(clock.running, isNull);
    clock.dispose();
  });

  test('a move completed after time ran out still flags', () {
    Side? flagged;
    final clock = makeClock(
      const ClockSetup.symmetric(
          TimeControl(Duration(seconds: 5), Duration(seconds: 3))),
      onFlag: (s) => flagged = s,
    );
    clock.moveMade(Side.white);
    now += const Duration(seconds: 7);
    clock.moveMade(Side.black); // no tick happened in between
    expect(flagged, Side.black);
    expect(clock.remaining(Side.black), Duration.zero);
    clock.dispose();
  });

  test('untimed clock never runs', () {
    final clock = makeClock(ClockSetup.untimed);
    clock.moveMade(Side.white);
    expect(clock.running, isNull);
    expect(clock.isTimed, isFalse);
    clock.dispose();
  });

  test('periodic ticker is cancelled on stop and dispose', () async {
    final clock = ChessClock(
      const ClockSetup.symmetric(TimeControl(Duration(minutes: 1))),
      tickInterval: const Duration(milliseconds: 5),
    );
    var notifications = 0;
    clock.addListener(() => notifications++);
    clock.moveMade(Side.white);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(notifications, greaterThan(2));
    clock.stop();
    final afterStop = notifications;
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(notifications, afterStop);
    clock.dispose();
  });

  test('formats clock readings', () {
    expect(formatClock(const Duration(minutes: 3)), '3:00');
    expect(formatClock(const Duration(seconds: 65)), '1:05');
    expect(formatClock(const Duration(seconds: 9, milliseconds: 450)), '0:09.4');
    expect(formatClock(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
  });
}
