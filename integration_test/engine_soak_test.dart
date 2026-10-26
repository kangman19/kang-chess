import 'dart:io';
import 'dart:math' as math;

import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kang_chess/src/core/chess_utils.dart';
import 'package:kang_chess/src/domain/bot_profile.dart';
import 'package:kang_chess/src/engine/bot_move_picker.dart';
import 'package:kang_chess/src/engine/engine_service.dart';
import 'package:kang_chess/src/engine/stockfish_transport.dart';
import 'package:kang_chess/src/game/game_controller.dart';
import 'package:kang_chess/src/review/review_controller.dart';

/// Real embedded Stockfish: correctness of bot moves and review, plus a
/// memory soak over repeated and cancelled searches.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  int rssMb() => ProcessInfo.currentRss ~/ (1024 * 1024);

  testWidgets('real engine: bots, review, and memory soak', (tester) async {
    await tester.runAsync(() async {
      final engine = EngineService(StockfishTransport());
      final random = math.Random(7);
      final picker = BotMovePicker(engine, random: random);

      // 1. Every bot returns a legal move from a middlegame position.
      final history = ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', 'g8f6'];
      var pos = Chess.initial as Position;
      for (final uci in history) {
        pos = pos.play(parseLegalUci(pos, uci)!);
      }
      for (final bot in BotProfile.all) {
        final sw = Stopwatch()..start();
        final move = await picker.pickMove(
          bot: bot,
          position: pos,
          startFen: kInitialFEN,
          history: history,
        );
        expect(move, isNotNull, reason: bot.name);
        expect(pos.isLegal(move!), isTrue, reason: bot.name);
        // ignore: avoid_print
        print('bot ${bot.name.padRight(16)} ${bot.ratingTag.padLeft(4)} '
            '-> ${toStandardUci(pos, move)} in ${sw.elapsedMilliseconds} ms');
      }

      // 2. Full engine finds mate in one and reports it.
      final mateIn1 = await engine.search(const SearchRequest(
        startFen: '6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1',
        depth: 10,
      ));
      expect(mateIn1.bestMove, 'd1d8');
      expect(mateIn1.best!.score.mate, 1);

      // 3. Review of a short game completes with a grade for every move.
      final moves = <PlayedMove>[];
      var p = Chess.initial as Position;
      for (final uci in ['e2e4', 'e7e5', 'd1h5', 'b8c6', 'f1c4', 'g8f6', 'h5f7']) {
        final m = parseLegalUci(p, uci)!;
        final captured = isCapture(p, m);
        final (next, san) = p.makeSan(m);
        moves.add(PlayedMove(
          move: m, san: san, uci: uci, fenAfter: next.fen,
          mover: p.turn, captured: captured,
        ));
        p = next;
      }
      final review = ReviewController(
        moves: moves,
        result: const GameResult(Side.white, GameEndReason.checkmate),
        playerSide: Side.white,
        engine: engine,
        depth: 12,
      )..start();
      while (!review.isFinished) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(review.error, isNull);
      expect(review.reviews, hasLength(moves.length));
      for (final r in review.reviews) {
        // ignore: avoid_print
        print('review ${r.ply}. ${r.played.san.padRight(6)} '
            '${r.classification.label.padRight(10)} eval ${r.evalWhite.display}');
      }
      // ...Nf6?? allows Qxf7#.
      expect(review.reviewAt(6)!.loss, greaterThan(0.2));
      review.dispose();

      // 4. Soak: repeated searches with every 3rd cancelled mid-search.
      final rssStart = rssMb();
      const rounds = 300;
      for (var i = 0; i < rounds; i++) {
        final cancel = CancelToken();
        final future = engine.search(
          SearchRequest(
            startFen: kInitialFEN,
            moves: history.take(i % history.length).toList(),
            options: EngineOptions(multiPv: 1 + i % 3, limitElo: i.isEven ? 1500 : null),
            movetime: const Duration(milliseconds: 20),
          ),
          cancel: cancel,
        );
        if (i % 3 == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          cancel.cancel();
        }
        await future;
        if (i == 50) {
          // ignore: avoid_print
          print('rss after warm-up: ${rssMb()} MB');
        }
      }
      final rssEnd = rssMb();
      // ignore: avoid_print
      print('rss start $rssStart MB, end $rssEnd MB after $rounds searches');
      expect(rssEnd - rssStart, lessThan(40),
          reason: 'memory should not grow with search count');

      await engine.dispose();
    });
  }, timeout: const Timeout(Duration(minutes: 10)));
}
