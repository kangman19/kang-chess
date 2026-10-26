import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kang_chess/src/core/chess_utils.dart';
import 'package:kang_chess/src/domain/bot_profile.dart';
import 'package:kang_chess/src/domain/time_control.dart';
import 'package:kang_chess/src/engine/engine_service.dart';
import 'package:kang_chess/src/game/game_controller.dart';

import '../support/fake_uci.dart';

NormalMove mv(String uci) => NormalMove.fromUci(uci);

/// A UCI_Elo bot: no humanizing delay, no random moves.
final BotProfile fastBot =
    BotProfile.all.firstWhere((b) => b.uciElo != null && !b.humanizedDelay);

(String?, List<String>) scripted(Position pos, Map<String, String> byBoard) {
  final uci = byBoard[pos.board.fen];
  if (uci == null) {
    final first = allLegalMoves(pos).first;
    final fallback = toStandardUci(pos, first);
    return (fallback, ['info depth 1 score cp 0 pv $fallback']);
  }
  return (uci, ['info depth 1 score cp 0 pv $uci']);
}

void main() {
  late FakeUciTransport transport;
  late EngineService engine;

  GameController newGame({Side player = Side.white}) => GameController(
        bot: fastBot,
        playerSide: player,
        clockSetup: ClockSetup.untimed,
        engine: engine,
      );

  tearDown(() => engine.dispose());

  test('bot replies after the player moves', () async {
    transport = FakeUciTransport();
    engine = EngineService(transport);
    final game = newGame()..start();
    expect(game.playerMove(mv('e2e4')), isTrue);
    expect(game.botThinking, isTrue);
    await pumpEventQueue();
    expect(game.moves, hasLength(2));
    expect(game.isPlayerTurn, isTrue);
    expect(game.botThinking, isFalse);
    game.dispose();
  });

  test('bot moves first when the player has Black', () async {
    transport = FakeUciTransport();
    engine = EngineService(transport);
    final game = newGame(player: Side.black)..start();
    await pumpEventQueue();
    expect(game.moves, hasLength(1));
    expect(game.isPlayerTurn, isTrue);
    game.dispose();
  });

  test('rejects illegal moves on the player turn', () {
    transport = FakeUciTransport();
    engine = EngineService(transport);
    final game = newGame()..start();
    expect(game.playerMove(mv('e2e5')), isFalse);
    expect(game.moves, isEmpty);
    game.dispose();
  });

  test('premove executes instantly after the bot moves', () async {
    transport = FakeUciTransport(holdSearches: true);
    engine = EngineService(transport);
    final game = newGame()..start();
    game.playerMove(mv('e2e4'));
    await pumpEventQueue();
    expect(game.playerMove(mv('d2d4')), isTrue); // queued as premove
    expect(game.premoves, [mv('d2d4')]);
    expect(game.displayBoard.pieceAt(Square.d4), Piece.whitePawn);

    transport.release();
    await pumpEventQueue();
    expect(game.moves.map((m) => m.uci).take(3).last, 'd2d4');
    expect(game.premoves, isEmpty);
    expect(game.botThinking, isTrue); // bot is answering the premove
    game.dispose();
  });

  test('premove made illegal by the bot is cancelled', () async {
    final afterE4 = Chess.initial.play(mv('e2e4'));
    transport = FakeUciTransport(
      holdSearches: true,
      chooser: (pos) => scripted(pos, {afterE4.board.fen: 'e7e5'}),
    );
    engine = EngineService(transport);
    final game = newGame()..start();
    game.playerMove(mv('e2e4'));
    await pumpEventQueue();
    game.playerMove(mv('e4e5'));
    game.playerMove(mv('d2d4'));
    expect(game.premoves, hasLength(2));

    transport.release();
    await pumpEventQueue();
    expect(game.moves, hasLength(2));
    expect(game.premoves, isEmpty);
    expect(game.premoveCancellations, 1);
    expect(game.isPlayerTurn, isTrue);
    game.dispose();
  });

  test('threefold repetition ends the game as a draw', () async {
    // Black shuffles its king's knight to mirror the player.
    final replies = <String, String>{};
    var pos = Chess.initial as Position;
    for (final (w, b) in [('g1f3', 'g8f6'), ('f3g1', 'f6g8')]) {
      pos = pos.play(mv(w));
      replies[pos.board.fen] = b;
      pos = pos.play(mv(b));
    }
    transport = FakeUciTransport(chooser: (p) => scripted(p, replies));
    engine = EngineService(transport);
    final game = newGame()..start();
    for (final w in ['g1f3', 'f3g1', 'g1f3', 'f3g1']) {
      expect(game.playerMove(mv(w)), isTrue);
      await pumpEventQueue();
    }
    expect(game.result?.reason, GameEndReason.threefold);
    expect(game.result?.winner, isNull);
    game.dispose();
  });

  test('resign and dispose stop the bot search', () async {
    transport = FakeUciTransport(holdSearches: true);
    engine = EngineService(transport);
    final game = newGame()..start();
    game.playerMove(mv('e2e4'));
    await pumpEventQueue();
    game.resign();
    expect(game.result?.winner, Side.black);
    expect(game.result?.reason, GameEndReason.resignation);
    expect(transport.sent.last, 'stop');
    await pumpEventQueue();
    expect(game.moves, hasLength(1)); // the stale bot reply was dropped
    game.dispose();
  });

  test('records standard UCI for castling', () async {
    transport = FakeUciTransport();
    engine = EngineService(transport);
    final game = newGame()..start();
    for (final w in ['e2e4', 'g1f3', 'f1c4']) {
      game.playerMove(mv(w));
      await pumpEventQueue();
    }
    expect(game.playerMove(mv('e1g1')), isTrue);
    final castle = game.moves[6];
    expect(castle.uci, 'e1g1');
    expect(castle.san, 'O-O');
    game.dispose();
  });
}
