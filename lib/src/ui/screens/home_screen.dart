import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../app.dart';
import '../board/chess_board.dart';
import 'new_game_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 12),
                Text('Kang Chess',
                    style: textTheme.displaySmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Offline bots · premoves · full game review',
                    style: textTheme.bodyLarge),
                const SizedBox(height: 24),
                ListenableBuilder(
                  listenable: settings,
                  builder: (context, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ChessBoard(
                      board: Board.standard,
                      orientation: Side.white,
                      theme: settings.theme,
                      pieceSet: settings.pieceSet,
                      showCoordinates: settings.showCoordinates,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56)),
                  icon: const Icon(Icons.smart_toy_outlined),
                  label: const Text('Play vs Bot'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NewGameScreen()),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52)),
                  icon: const Icon(Icons.palette_outlined),
                  label: const Text('Board & Settings'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
