import 'package:flutter_test/flutter_test.dart';
import 'package:kang_chess/src/domain/score.dart';
import 'package:kang_chess/src/engine/uci.dart';

void main() {
  test('parses multipv info with centipawn score', () {
    final pv = parseInfoLine(
        'info depth 14 seldepth 20 multipv 2 score cp -35 nodes 12345 nps 900000 '
        'hashfull 3 tbhits 0 time 13 pv e7e5 g1f3 b8c6')!;
    expect(pv.depth, 14);
    expect(pv.multipv, 2);
    expect(pv.score, const Score.cp(-35));
    expect(pv.moves, ['e7e5', 'g1f3', 'b8c6']);
  });

  test('parses mate scores and defaults multipv to 1', () {
    final pv = parseInfoLine('info depth 5 score mate -2 pv h7h8')!;
    expect(pv.multipv, 1);
    expect(pv.score, const Score.mate(-2));
  });

  test('ignores bound scores, strings and lines without pv', () {
    expect(parseInfoLine('info depth 9 score cp 20 lowerbound pv e2e4'), isNull);
    expect(parseInfoLine('info depth 9 score cp 20 upperbound pv e2e4'), isNull);
    expect(parseInfoLine('info string NNUE evaluation enabled'), isNull);
    expect(parseInfoLine('info depth 3 currmove e2e4 currmovenumber 1'), isNull);
    expect(parseInfoLine('readyok'), isNull);
  });

  test('parses bestmove lines', () {
    expect(parseBestMove('bestmove e2e4 ponder e7e5'),
        (isBestMove: true, move: 'e2e4'));
    expect(parseBestMove('bestmove (none)'), (isBestMove: true, move: null));
    expect(parseBestMove('info depth 1'), (isBestMove: false, move: null));
  });
}
