import 'package:dartchess/dartchess.dart';

/// Initial time plus Fischer increment for one side.
class TimeControl {
  const TimeControl(this.initial, [this.increment = Duration.zero]);

  final Duration initial;
  final Duration increment;

  String get label {
    final base = initial.inSeconds % 60 == 0
        ? '${initial.inMinutes} min'
        : '${initial.inSeconds}s';
    return increment == Duration.zero
        ? base
        : '$base + ${increment.inSeconds}s';
  }

  @override
  bool operator ==(Object other) =>
      other is TimeControl &&
      other.initial == initial &&
      other.increment == increment;

  @override
  int get hashCode => Object.hash(initial, increment);
}

/// Clock configuration for a game. Each side may have its own control.
class ClockSetup {
  const ClockSetup({this.white, this.black})
      : assert((white == null) == (black == null));

  /// Both sides play with the same [control].
  const ClockSetup.symmetric(TimeControl control)
      : white = control,
        black = control;

  /// Player and bot have independent controls.
  factory ClockSetup.forPlayer({
    required Side playerSide,
    required TimeControl player,
    required TimeControl bot,
  }) =>
      playerSide == Side.white
          ? ClockSetup(white: player, black: bot)
          : ClockSetup(white: bot, black: player);

  static const untimed = ClockSetup();

  final TimeControl? white;
  final TimeControl? black;

  bool get isTimed => white != null;

  TimeControl? of(Side side) => side == Side.white ? white : black;

  String get label {
    if (!isTimed) return 'Untimed';
    if (white == black) return white!.label;
    return '${white!.label} vs ${black!.label}';
  }
}

/// A named game-mode preset shown in the new-game screen.
class TimeControlPreset {
  const TimeControlPreset(this.name, this.control);

  final String name;

  /// `null` means untimed.
  final TimeControl? control;

  ClockSetup get setup =>
      control == null ? ClockSetup.untimed : ClockSetup.symmetric(control!);

  static const presets = [
    TimeControlPreset('Blitz', TimeControl(Duration(minutes: 3))),
    TimeControlPreset(
        'Blitz', TimeControl(Duration(minutes: 3), Duration(seconds: 2))),
    TimeControlPreset('Rapid', TimeControl(Duration(minutes: 10))),
    TimeControlPreset(
        'Rapid', TimeControl(Duration(minutes: 15), Duration(seconds: 10))),
    TimeControlPreset('Untimed', null),
  ];
}
