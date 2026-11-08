import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kang_chess/src/app.dart';
import 'package:kang_chess/src/domain/bot_profile.dart';
import 'package:kang_chess/src/domain/time_control.dart';
import 'package:kang_chess/src/engine/engine_service.dart';
import 'package:kang_chess/src/settings/settings_controller.dart';
import 'package:kang_chess/src/ui/board/chess_board.dart';
import 'package:kang_chess/src/ui/screens/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_uci.dart';

void main() {
  testWidgets('premoves can be entered by tap and by drag', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsController.load();
    // The bot never finishes thinking, so every later move is a premove.
    final engine = EngineService(FakeUciTransport(holdSearches: true));
    addTearDown(engine.dispose);

    await tester.pumpWidget(AppScope(
      engine: engine,
      settings: settings,
      child: MaterialApp(
        home: GameScreen(
          // Always asks the engine, never a random instant move.
          bot: BotProfile.all.firstWhere((b) => b.uciElo != null),
          playerSide: Side.white,
          clockSetup: ClockSetup.untimed,
        ),
      ),
    ));

    final board = tester.getRect(find.byType(ChessBoard));
    Offset at(String name) {
      final s = Square.fromName(name);
      final sq = board.width / 8;
      return board.topLeft +
          Offset(s.file * sq + sq / 2, (7 - s.rank) * sq + sq / 2);
    }

    Future<void> tap(String square) async {
      await tester.tapAt(at(square));
      await tester.pump();
    }

    // A real move on the player's turn.
    await tap('e2');
    await tap('e4');
    expect(find.text('1. e4'), findsOneWidget);

    // Premove by tapping.
    await tap('d2');
    await tap('d4');
    expect(find.text('Premoves (1)'), findsOneWidget);

    // Premove by dragging.
    await tester.dragFrom(at('g1'), at('f3') - at('g1'));
    await tester.pump();
    expect(find.text('Premoves (2)'), findsOneWidget);

    // Tapping an empty square clears the queue.
    await tap('a5');
    expect(find.textContaining('Premoves'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });
}
