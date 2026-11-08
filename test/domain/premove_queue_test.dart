import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kang_chess/src/domain/premove_queue.dart';

NormalMove mv(String uci) => NormalMove.fromUci(uci);

Position fen(String f) => Chess.fromSetup(Setup.parseFen(f));

void main() {
  test('queues chained premoves against the projected board', () {
    final queue = PremoveQueue();
    final board = Chess.initial.board;
    expect(queue.add(board, Side.white, mv('e2e4')), isTrue);
    // e4 pawn exists only on the projected board.
    expect(queue.add(board, Side.white, mv('e4e5')), isTrue);
    expect(queue.project(board).pieceAt(Square.e5), Piece.whitePawn);
    expect(queue.project(board).pieceAt(Square.e2), isNull);
  });

  test('rejects wrong geometry, empty sources and other side pieces', () {
    final queue = PremoveQueue();
    final board = Chess.initial.board;
    expect(queue.add(board, Side.white, mv('g1g3')), isFalse); // knight shape
    expect(queue.add(board, Side.white, mv('e4e5')), isFalse); // no piece
    expect(queue.add(board, Side.white, mv('e7e5')), isFalse); // not ours
    expect(queue.isEmpty, isTrue);
  });

  test('allows recapture premoves onto own pieces', () {
    final queue = PremoveQueue();
    final board = Chess.initial.board;
    expect(queue.add(board, Side.white, mv('d1d2')), isTrue); // queen
    expect(queue.add(board, Side.white, mv('g1e2')), isTrue); // knight
    // Pawns never recapture straight ahead, and the king's two-square move
    // is castling, not a capture.
    final pos = fen('4k3/8/8/8/8/4P3/4P3/4K1N1 w - - 0 1');
    final q2 = PremoveQueue();
    expect(q2.add(pos.board, Side.white, mv('e2e3')), isFalse);
    expect(q2.add(pos.board, Side.white, mv('e1g1')), isFalse);
    expect(q2.add(pos.board, Side.white, mv('e1e2')), isTrue); // king
  });

  test('recapture premove plays once the opponent has taken', () {
    // White pawn d4 defended by the queen; black bishop is about to take.
    final before = fen('4k3/8/8/2b5/3P4/8/8/3QK3 b - - 0 1');
    final queue = PremoveQueue()..add(before.board, Side.white, mv('d1d4'));
    expect(queue.moves, [mv('d1d4')]);
    final taken = before.play(mv('c5d4'));
    expect(queue.takeLegal(taken), mv('d1d4'));
  });

  test('recapture premove is cancelled if nothing was taken', () {
    final before = fen('4k3/8/8/2b5/3P4/8/8/3QK3 b - - 0 1');
    final queue = PremoveQueue()..add(before.board, Side.white, mv('d1d4'));
    final quiet = before.play(mv('e8e7'));
    expect(queue.takeLegal(quiet), isNull);
    expect(queue.isEmpty, isTrue);
  });

  test('allows pawn diagonal premove onto an empty square', () {
    final queue = PremoveQueue();
    expect(queue.add(Chess.initial.board, Side.white, mv('e2d3')), isTrue);
  });

  test('executes the head when legal', () {
    final queue = PremoveQueue()..add(Chess.initial.board, Side.white, mv('e2e4'));
    final move = queue.takeLegal(Chess.initial);
    expect(move, mv('e2e4'));
    expect(queue.isEmpty, isTrue);
  });

  test('illegal head cancels the whole queue', () {
    // White pawn e2, black bishop will block: premove e2e4 then e4e5.
    final pos = fen('4k3/8/8/8/4b3/8/4P3/4K3 w - - 0 1');
    final queue = PremoveQueue()
      ..add(pos.board, Side.white, mv('e2e4'))
      ..add(pos.board, Side.white, mv('e4e5'));
    expect(queue.moves, hasLength(2));
    // e2e4 is blocked by the bishop on e4: illegal.
    expect(queue.takeLegal(pos), isNull);
    expect(queue.isEmpty, isTrue);
  });

  test('castling premove is normalized for execution', () {
    final pos = fen('4k3/8/8/8/8/8/8/4K2R w K - 0 1');
    final queue = PremoveQueue()..add(pos.board, Side.white, mv('e1g1'));
    expect(queue.project(pos.board).pieceAt(Square.f1), Piece.whiteRook);
    final move = queue.takeLegal(pos);
    expect(move, isNotNull);
    expect(pos.play(move!).board.pieceAt(Square.g1), Piece.whiteKing);
  });

  test('promotion premoves auto-queen', () {
    final pos = fen('k7/4P3/8/8/8/8/8/4K3 w - - 0 1');
    final queue = PremoveQueue()..add(pos.board, Side.white, mv('e7e8'));
    expect(queue.moves.single.promotion, Role.queen);
  });

  test('caps the queue length', () {
    final queue = PremoveQueue();
    final board = fen('4k3/8/8/8/8/8/8/R3K3 w - - 0 1').board;
    var accepted = 0;
    for (var i = 0; i < 20; i++) {
      final uci = i.isEven ? 'a1a2' : 'a2a1';
      if (queue.add(board, Side.white, mv(uci))) accepted++;
    }
    expect(accepted, PremoveQueue.maxLength);
  });
}
