import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kang_chess/src/engine/engine_service.dart';

import '../support/fake_uci.dart';

SearchRequest req({int multiPv = 1, int? elo, List<String> moves = const []}) =>
    SearchRequest(
      startFen: kInitialFEN,
      moves: moves,
      options: EngineOptions(multiPv: multiPv, limitElo: elo),
      depth: 5,
    );

void main() {
  test('runs the UCI handshake once and returns the best move', () async {
    final transport = FakeUciTransport();
    final engine = EngineService(transport);
    final result = await engine.search(req());
    expect(result.bestMove, isNotNull);
    expect(result.best?.depth, 1);
    await engine.search(req(moves: ['e2e4']));
    expect(transport.sent.where((c) => c == 'uci'), hasLength(1));
    expect(transport.sent, contains('position fen $kInitialFEN moves e2e4'));
    await engine.dispose();
    expect(transport.disposed, isTrue);
  });

  test('serializes concurrent searches', () async {
    final transport = FakeUciTransport();
    final engine = EngineService(transport);
    final results = await Future.wait([
      engine.search(req(moves: ['e2e4'])),
      engine.search(req(moves: ['d2d4'])),
      engine.search(req(moves: ['c2c4'])),
    ]);
    expect(results.every((r) => r.bestMove != null), isTrue);
    // Each go is preceded by its own position command.
    final commands = transport.sent
        .where((c) => c.startsWith('position') || c.startsWith('go'))
        .toList();
    expect(commands, hasLength(6));
    for (var i = 0; i < 6; i += 2) {
      expect(commands[i], startsWith('position'));
      expect(commands[i + 1], startsWith('go'));
    }
    await engine.dispose();
  });

  test('only re-sends options that changed and clamps UCI_Elo', () async {
    final transport = FakeUciTransport();
    final engine = EngineService(transport);
    await engine.search(req(elo: 900));
    await engine.search(req(elo: 900));
    await engine.search(req());
    final options =
        transport.sent.where((c) => c.startsWith('setoption')).toList();
    expect(options.where((c) => c.contains('UCI_Elo')), [
      'setoption name UCI_Elo value ${EngineService.minUciElo}',
    ]);
    expect(
      options.where((c) => c.contains('UCI_LimitStrength')),
      [
        'setoption name UCI_LimitStrength value true',
        'setoption name UCI_LimitStrength value false',
      ],
    );
    await engine.dispose();
  });

  test('cancel sends stop and the next search is not affected', () async {
    final transport = FakeUciTransport(holdSearches: true);
    final engine = EngineService(transport);
    final cancel = CancelToken();
    final first = engine.search(req(), cancel: cancel);
    await pumpEventQueue();
    expect(transport.goCount, 1);
    cancel.cancel();
    await first;
    expect(transport.sent.last, 'stop');

    transport.holdSearches = false;
    final second = await engine.search(req(moves: ['e2e4']));
    expect(second.bestMove, isNotNull);
    await engine.dispose();
  });

  test('searches cancelled while queued never reach the engine', () async {
    final transport = FakeUciTransport(holdSearches: true);
    final engine = EngineService(transport);
    final running = engine.search(req());
    final cancel = CancelToken();
    final queued = engine.search(req(moves: ['e2e4']), cancel: cancel);
    cancel.cancel();
    await pumpEventQueue();
    transport.release();
    await running;
    final result = await queued;
    expect(result.bestMove, isNull);
    expect(transport.goCount, 1);
    await engine.dispose();
  });

  test('dispose stops a running search without a cancel token', () async {
    final transport = FakeUciTransport(holdSearches: true);
    final engine = EngineService(transport);
    final running = engine.search(req());
    await pumpEventQueue();
    expect(transport.goCount, 1);
    await engine.dispose();
    await running;
    expect(transport.sent, contains('stop'));
    expect(transport.disposed, isTrue);
    await expectLater(engine.search(req()), throwsStateError);
    await engine.dispose(); // idempotent
  });

  test('dispose during the handshake abandons the job before go', () async {
    final transport = FakeUciTransport(holdSearches: true);
    final engine = EngineService(transport);
    final running = engine.search(req());
    // Dispose before the queued job has reached `go`.
    await engine.dispose();
    expect(await running, same(SearchResult.empty));
    expect(transport.goCount, 0);
    expect(transport.disposed, isTrue);
  });
}
