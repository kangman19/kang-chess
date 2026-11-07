import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kang_chess/src/ui/board/board_theme.dart';
import 'package:kang_chess/src/ui/board/chess_board.dart';
import 'package:kang_chess/src/ui/board/piece_set.dart';

// Kings and rooks only, both sides may castle either way.
const _castleFen = 'r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1';
const _size = 400.0;

Offset _center(String name) {
  final s = Square.fromName(name);
  const sq = _size / 8;
  return Offset(s.file * sq + sq / 2, (7 - s.rank) * sq + sq / 2);
}

Future<List<NormalMove>> _pump(
  WidgetTester tester, {
  required Position position,
  bool premove = false,
}) async {
  final moves = <NormalMove>[];
  final legal = premove
      ? const <Square, Set<Square>>{}
      : {
          for (final MapEntry(key: from, value: dests)
              in makeLegalMoves(position).entries)
            from: {
              for (final to in dests)
                if (!position.board.bySide(position.turn).has(to)) to,
            },
        };
  await tester.pumpWidget(MaterialApp(
    home: Align(
      alignment: Alignment.topLeft,
      child: SizedBox.square(
        dimension: _size,
        child: ChessBoard(
          board: position.board,
          orientation: Side.white,
          theme: BoardTheme.all.first,
          pieceSet: PieceSet.glyph,
          interactiveSide: Side.white,
          legalMoves: legal,
          canPremove: premove,
          onMove: moves.add,
        ),
      ),
    ),
  ));
  return moves;
}

Future<void> _tap(WidgetTester tester, String square) async {
  await tester.tapAt(_center(square));
  await tester.pump();
}

void main() {
  final position = Chess.fromSetup(Setup.parseFen(_castleFen));

  testWidgets('tapping king then rook castles', (tester) async {
    final moves = await _pump(tester, position: position);
    await _tap(tester, 'e1');
    await _tap(tester, 'h1');
    expect(moves.map((m) => m.uci), ['e1g1']);
  });

  testWidgets('tapping rook then king castles queenside', (tester) async {
    final moves = await _pump(tester, position: position);
    await _tap(tester, 'a1');
    await _tap(tester, 'e1');
    expect(moves.map((m) => m.uci), ['e1c1']);
  });

  testWidgets('dragging rook onto king castles', (tester) async {
    final moves = await _pump(tester, position: position);
    await tester.dragFrom(_center('h1'), _center('e1') - _center('h1'));
    await tester.pump();
    expect(moves.map((m) => m.uci), ['e1g1']);
  });

  testWidgets('king onto rook does nothing when castling is illegal',
      (tester) async {
    final noRights = Chess.fromSetup(
        Setup.parseFen('r3k2r/8/8/8/8/8/8/R3K2R w - - 0 1'));
    final moves = await _pump(tester, position: noRights);
    await _tap(tester, 'e1');
    await _tap(tester, 'h1');
    expect(moves, isEmpty);
  });

  testWidgets('castling by king onto rook is offered as a premove',
      (tester) async {
    final moves = await _pump(tester, position: position, premove: true);
    await _tap(tester, 'h1');
    await _tap(tester, 'e1');
    expect(moves.map((m) => m.uci), ['e1g1']);
  });

  testWidgets('premoves reject impossible piece geometry', (tester) async {
    final moves = await _pump(tester, position: position, premove: true);
    await _tap(tester, 'a1');
    await _tap(tester, 'b2'); // rook cannot move diagonally
    expect(moves, isEmpty);
    await _tap(tester, 'a1');
    await _tap(tester, 'a5');
    expect(moves.map((m) => m.uci), ['a1a5']);
  });
}
