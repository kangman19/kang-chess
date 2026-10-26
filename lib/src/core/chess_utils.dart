import 'package:dartchess/dartchess.dart';

/// Piece values used for material counting (sacrifice detection, display).
const Map<Role, int> pieceValues = {
  Role.pawn: 1,
  Role.knight: 3,
  Role.bishop: 3,
  Role.rook: 5,
  Role.queen: 9,
  Role.king: 0,
};

/// Total material of [side] on [board], in pawn units.
int materialOf(Board board, Side side) {
  var total = 0;
  for (final (_, piece) in board.pieces) {
    if (piece.color == side) total += pieceValues[piece.role]!;
  }
  return total;
}

/// Material balance from [side]'s point of view.
int materialBalance(Board board, Side side) =>
    materialOf(board, side) - materialOf(board, side.opposite);

/// Formats a legal [move] of [pos] as standard UCI.
///
/// dartchess encodes castling as king-takes-rook; UCI engines and our move
/// history use the king's two-square destination (e1g1, e8c8).
String toStandardUci(Position pos, NormalMove move) {
  final piece = pos.board.pieceAt(move.from);
  if (piece != null && piece.role == Role.king) {
    final target = pos.board.pieceAt(move.to);
    final ontoOwnRook = target != null &&
        target.color == piece.color &&
        target.role == Role.rook;
    final dx = move.to.file - move.from.file;
    if (ontoOwnRook || dx.abs() == 2) {
      final kingSide = ontoOwnRook ? move.to.file > move.from.file : dx > 0;
      final to = Square.fromCoords(kingSide ? File.g : File.c, move.from.rank);
      return NormalMove(from: move.from, to: to).uci;
    }
  }
  return move.uci;
}

/// Parses a UCI move and returns it in dartchess form if legal in [pos].
NormalMove? parseLegalUci(Position pos, String uci) {
  final parsed = Move.parse(uci);
  if (parsed is! NormalMove) return null;
  final move = pos.normalizeMove(parsed) as NormalMove;
  return pos.isLegal(move) ? move : null;
}

/// Returns [move] normalized for [pos] if legal, otherwise `null`.
NormalMove? legalOrNull(Position pos, NormalMove move) {
  final normalized = pos.normalizeMove(move) as NormalMove;
  return pos.isLegal(normalized) ? normalized : null;
}

/// All legal moves of [pos] as a flat list (castling in dartchess form).
List<NormalMove> allLegalMoves(Position pos) => [
      for (final MapEntry(key: from, value: dests) in pos.legalMoves.entries)
        for (final to in dests.squares)
          ...(_isPromotion(pos, from, to)
              ? [
                  for (final role in const [
                    Role.queen,
                    Role.rook,
                    Role.bishop,
                    Role.knight,
                  ])
                    NormalMove(from: from, to: to, promotion: role),
                ]
              : [NormalMove(from: from, to: to)]),
    ];

bool _isPromotion(Position pos, Square from, Square to) =>
    pos.board.pawns.has(from) && SquareSet.backranks.has(to);

/// Whether moving the piece on [from] to [to] needs a promotion choice.
bool needsPromotion(Board board, Square from, Square to) =>
    board.pawns.has(from) && SquareSet.backranks.has(to);

/// Whether [move] captures something in [pos], including en passant.
bool isCapture(Position pos, NormalMove move) {
  final target = pos.board.pieceAt(move.to);
  if (target != null && target.color != pos.turn) return true;
  return pos.board.pawns.has(move.from) &&
      move.to == pos.epSquare &&
      move.from.file != move.to.file;
}
