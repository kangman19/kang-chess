import 'dart:math' as math;

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../domain/bot_profile.dart';
import '../../domain/time_control.dart';
import '../bot_avatar.dart';
import 'game_screen.dart';

enum _ColorChoice { white, random, black }

class NewGameScreen extends StatefulWidget {
  const NewGameScreen({super.key});

  @override
  State<NewGameScreen> createState() => _NewGameScreenState();
}

class _NewGameScreenState extends State<NewGameScreen> {
  BotProfile _bot = BotProfile.all[5];
  _ColorChoice _color = _ColorChoice.random;

  /// Index into [TimeControlPreset.presets], or `null` for custom.
  int? _preset = 2;
  TimeControl _customPlayer =
      const TimeControl(Duration(minutes: 5), Duration(seconds: 2));
  TimeControl _customBot = const TimeControl(Duration(minutes: 1));

  static const _minuteOptions = [1, 2, 3, 5, 10, 15, 30, 60];
  static const _incrementOptions = [0, 1, 2, 3, 5, 10, 20, 30];

  void _start() {
    final side = switch (_color) {
      _ColorChoice.white => Side.white,
      _ColorChoice.black => Side.black,
      _ColorChoice.random =>
        math.Random().nextBool() ? Side.white : Side.black,
    };
    final preset = _preset;
    final clock = preset != null
        ? TimeControlPreset.presets[preset].setup
        : ClockSetup.forPlayer(
            playerSide: side, player: _customPlayer, bot: _customBot);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            GameScreen(bot: _bot, playerSide: side, clockSetup: clock),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('New Game')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Text('Opponent', style: textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final bot in BotProfile.all) _botTile(bot),
                  const SizedBox(height: 16),
                  Text('Play as', style: textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SegmentedButton<_ColorChoice>(
                    segments: const [
                      ButtonSegment(value: _ColorChoice.white, label: Text('White')),
                      ButtonSegment(value: _ColorChoice.random, label: Text('Random')),
                      ButtonSegment(value: _ColorChoice.black, label: Text('Black')),
                    ],
                    selected: {_color},
                    onSelectionChanged: (s) => setState(() => _color = s.first),
                  ),
                  const SizedBox(height: 16),
                  Text('Time control', style: textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < TimeControlPreset.presets.length; i++)
                        ChoiceChip(
                          label: Text(_presetLabel(TimeControlPreset.presets[i])),
                          selected: _preset == i,
                          onSelected: (_) => setState(() => _preset = i),
                        ),
                      ChoiceChip(
                        label: const Text('Custom'),
                        selected: _preset == null,
                        onSelected: (_) => setState(() => _preset = null),
                      ),
                    ],
                  ),
                  if (_preset == null) ...[
                    const SizedBox(height: 12),
                    _customRow('You', _customPlayer,
                        (c) => setState(() => _customPlayer = c)),
                    _customRow('Bot', _customBot,
                        (c) => setState(() => _customBot = c)),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56)),
                onPressed: _start,
                child: Text('Play ${_bot.name}'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _presetLabel(TimeControlPreset p) =>
      p.control == null ? p.name : '${p.name} ${p.control!.label}';

  Widget _botTile(BotProfile bot) {
    final selected = bot.id == _bot.id;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: selected ? scheme.primaryContainer : null,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: BotAvatar(bot: bot),
        title: Row(
          children: [
            Flexible(child: Text(bot.name, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            _Tag(bot.ratingTag),
            const SizedBox(width: 4),
            _Tag(bot.style.label, subtle: true),
          ],
        ),
        subtitle: Text(bot.blurb),
        onTap: () => setState(() => _bot = bot),
      ),
    );
  }

  Widget _customRow(
      String who, TimeControl control, ValueChanged<TimeControl> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text(who)),
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: control.initial.inMinutes,
              decoration: const InputDecoration(labelText: 'Minutes'),
              items: [
                for (final m in _minuteOptions)
                  DropdownMenuItem(value: m, child: Text('$m')),
              ],
              onChanged: (m) => onChanged(
                  TimeControl(Duration(minutes: m!), control.increment)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: control.increment.inSeconds,
              decoration: const InputDecoration(labelText: 'Increment (s)'),
              items: [
                for (final s in _incrementOptions)
                  DropdownMenuItem(value: s, child: Text('$s')),
              ],
              onChanged: (s) => onChanged(
                  TimeControl(control.initial, Duration(seconds: s!))),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {this.subtle = false});

  final String text;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: subtle ? scheme.surfaceContainerHighest : scheme.tertiary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: subtle ? scheme.onSurfaceVariant : scheme.onTertiary,
        ),
      ),
    );
  }
}
