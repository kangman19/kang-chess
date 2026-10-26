import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../app.dart';
import '../../settings/settings_controller.dart';
import '../board/board_theme.dart';
import '../board/chess_board.dart';
import '../board/piece_set.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static final _previewBoard =
      Board.parseFen('r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R');

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Board & Settings')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: ChessBoard(
                    board: _previewBoard,
                    orientation: Side.white,
                    theme: settings.theme,
                    pieceSet: settings.pieceSet,
                    showCoordinates: settings.showCoordinates,
                    lastMove: (Square.f1, Square.c4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Board', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: BoardTheme.all.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) =>
                    _ThemeSwatch(theme: BoardTheme.all[i], settings: settings),
              ),
            ),
            const SizedBox(height: 16),
            Text('Pieces', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final set in PieceSet.values)
                  ChoiceChip(
                    label: Text(set.label),
                    selected: settings.pieceSet == set,
                    onSelected: (_) => settings.pieceSet = set,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Show coordinates'),
              value: settings.showCoordinates,
              onChanged: (v) => settings.showCoordinates = v,
            ),
            SwitchListTile(
              title: const Text('Show legal moves'),
              value: settings.showLegalMoves,
              onChanged: (v) => settings.showLegalMoves = v,
            ),
            SwitchListTile(
              title: const Text('Highlight last move'),
              value: settings.highlightLastMove,
              onChanged: (v) => settings.highlightLastMove = v,
            ),
            SwitchListTile(
              title: const Text('Premoves'),
              subtitle: const Text('Queue moves while the bot is thinking'),
              value: settings.premovesEnabled,
              onChanged: (v) => settings.premovesEnabled = v,
            ),
            const SizedBox(height: 8),
            Text('Review depth', style: textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Higher is more accurate but slower.',
                style: textTheme.bodySmall),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: [
                for (final d in SettingsController.reviewDepths)
                  ButtonSegment(value: d, label: Text('$d')),
              ],
              selected: {settings.reviewDepth},
              onSelectionChanged: (s) => settings.reviewDepth = s.first,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({required this.theme, required this.settings});

  final BoardTheme theme;
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final selected = settings.theme.id == theme.id;
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => settings.theme = theme,
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? scheme.primary : Colors.transparent,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: GridView.count(
                crossAxisCount: 4,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (var i = 0; i < 16; i++)
                    ColoredBox(
                      color: (i ~/ 4 + i % 4).isEven ? theme.light : theme.dark,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(theme.name, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
