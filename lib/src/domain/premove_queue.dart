import 'package:dartchess/dartchess.dart';

import '../core/chess_utils.dart';

/// Queued premoves for one side.
///
/// Entry is checked only for piece geometry on a projected board (the current
/// board with earlier premoves applied); full legality is checked when the
/// head of the queue is executed. An illegal head clears the whole queue,
/// because later premoves assumed it would succeed.
class PremoveQueue {
  static const maxLength = 10;

  final List<NormalMove> _moves = [];

  List<NormalMove> get moves => List.unmodifiable(_moves);
  bool get isEmpty => _moves.isEmpty;
  bool get isNotEmpty => _moves.isNotEmpty;

  void clear() => _moves.clear();

  /// [board] with all queued premoves applied.
  Board project(Board board) {
    var projected = board;
    for (final move in _moves) {
      projected = _applyProjected(projected, move);
    }
    return projected;
  }

  /// Queues [move] for [side]. Returns whether it was accepted.
  bool add(Board current, Side side, NormalMove move) {
    if (_moves.length >= maxLength || move.from == move.to) return false;
    final board = project(current);
    final piece = board.pieceAt(move.from);
    if (piece == null || piece.color != side) return false;
    if (!isPremoveShape(piece, move.from, move.to)) return false;
    final target = board.pieceAt(move.to);
    if (target != null &&
        target.color == side &&
        !canPremoveOntoOwn(piece, move.from, move.to)) {
      return false;
    }
    final promote = needsPromotion(board, move.from, move.to);
    _moves.add(NormalMove(
      from: move.from,
      to: move.to,
      promotion: promote ? Role.queen : null,
    ));
    return true;
  }

  /// Removes and returns the head if it is legal in [pos].
  ///
  /// Returns `null` and clears the queue when the head is illegal.
  NormalMove? takeLegal(Position pos) {
    if (_moves.isEmpty) return null;
    final head = _moves.removeAt(0);
    final legal = legalOrNull(pos, head);
    if (legal == null) _moves.clear();
    return legal;
  }
}

/// Whether [piece] could ever move from [from] to [to], ignoring blockers.
bool isPremoveShape(Piece piece, Square from, Square to) {
  final dx = to.file - from.file;
  final dy = to.rank - from.rank;
  if (dx == 0 && dy == 0) return false;
  final white = piece.color == Side.white;
  switch (piece.role) {
    case Role.pawn:
      final dir = white ? 1 : -1;
      final startRank = white ? 1 : 6;
      return (dx == 0 && dy == dir) ||
          (dx == 0 && dy == 2 * dir && from.rank == startRank) ||
          (dx.abs() == 1 && dy == dir);
    case Role.knight:
      return (dx.abs() == 1 && dy.abs() == 2) ||
          (dx.abs() == 2 && dy.abs() == 1);
    case Role.bishop:
      return dx.abs() == dy.abs();
    case Role.rook:
      return dx == 0 || dy == 0;
    case Role.queen:
      return dx.abs() == dy.abs() || dx == 0 || dy == 0;
    case Role.king:
      final homeRank = white ? 0 : 7;
      return (dx.abs() <= 1 && dy.abs() <= 1) ||
          (dy == 0 && dx.abs() == 2 && from.file == 4 && from.rank == homeRank);
  }
}

/// Whether [piece] may premove from [from] onto a square its own side holds:
/// a planned recapture in case the opponent takes there. It only plays if a
/// capture has happened by then. Pawns recapture diagonally only, and a king
/// two-square move is castling, never a capture.
bool canPremoveOntoOwn(Piece piece, Square from, Square to) =>
    switch (piece.role) {
      Role.pawn => from.file != to.file,
      Role.king => (to.file - from.file).abs() <= 1,
      _ => true,
    };

Board _applyProjected(Board board, NormalMove move) {
  final piece = board.pieceAt(move.from);
  if (piece == null) return board;
  var next = board.removePieceAt(move.from);
  final dx = move.to.file - move.from.file;
  if (piece.role == Role.king && dx.abs() == 2) {
    final rookFrom = Square.fromCoords(dx > 0 ? File.h : File.a, move.from.rank);
    final rookTo = Square.fromCoords(dx > 0 ? File.f : File.d, move.from.rank);
    final rook = next.pieceAt(rookFrom);
    if (rook != null && rook.role == Role.rook && rook.color == piece.color) {
      next = next.removePieceAt(rookFrom).setPieceAt(rookTo, rook);
    }
  }
  final placed =
      move.promotion != null ? piece.copyWith(role: move.promotion) : piece;
  return next.setPieceAt(move.to, placed);
}
