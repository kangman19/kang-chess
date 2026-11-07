import 'dart:math' as math;

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../core/chess_utils.dart';
import '../../domain/move_classification.dart';
import '../../domain/premove_queue.dart';
import '../move_class_style.dart';
import 'board_theme.dart';
import 'piece_set.dart';

class BoardArrow {
  const BoardArrow(this.from, this.to, this.color);

  final Square from;
  final Square to;
  final Color color;
}

/// Interactive chess board.
///
/// When [legalMoves] holds the source square, only those targets are
/// accepted. When [canPremove] is set, any premove-shaped target is offered
/// to [onMove] and the owner decides. Dropping the king on its rook (or the
/// rook on its king) is sent as castling: king two squares.
class ChessBoard extends StatefulWidget {
  const ChessBoard({
    super.key,
    required this.board,
    required this.orientation,
    required this.theme,
    required this.pieceSet,
    this.interactiveSide,
    this.legalMoves = const {},
    this.canPremove = false,
    this.lastMove,
    this.checkSquare,
    this.premoves = const [],
    this.arrows = const [],
    this.badge,
    this.showCoordinates = true,
    this.showLegalMoves = true,
    this.highlightLastMove = true,
    this.onMove,
    this.onEmptyTap,
  });

  final Board board;
  final Side orientation;
  final BoardTheme theme;
  final PieceSet pieceSet;
  final Side? interactiveSide;
  final Map<Square, Set<Square>> legalMoves;
  final bool canPremove;
  final (Square, Square)? lastMove;
  final Square? checkSquare;
  final List<NormalMove> premoves;
  final List<BoardArrow> arrows;
  final (Square, MoveClass)? badge;
  final bool showCoordinates;
  final bool showLegalMoves;
  final bool highlightLastMove;
  final void Function(NormalMove move)? onMove;
  final VoidCallback? onEmptyTap;

  @override
  State<ChessBoard> createState() => _ChessBoardState();
}

class _ChessBoardState extends State<ChessBoard> {
  late PiecePainter _pieces = PiecePainter(widget.pieceSet);
  Square? _selected;
  Square? _dragFrom;
  Offset? _dragPosition;
  double _squareSize = 0;

  @override
  void didUpdateWidget(ChessBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pieceSet != widget.pieceSet) {
      _pieces = PiecePainter(widget.pieceSet);
    }
    // Drop a selection that no longer points at one of our pieces.
    final selected = _selected;
    if (selected != null && !_isOwnPiece(selected)) _selected = null;
  }

  bool get _interactive =>
      widget.interactiveSide != null && widget.onMove != null;

  bool _isOwnPiece(Square square) =>
      widget.board.pieceAt(square)?.color == widget.interactiveSide;

  bool _isTarget(Square from, Square to) {
    if (from == to) return false;
    final castle = _castleMove(from, to);
    final legal = widget.legalMoves[castle?.from ?? from];
    if (legal != null) return legal.contains(castle?.to ?? to);
    if (!widget.canPremove) return false;
    if (castle != null) return true;
    final piece = widget.board.pieceAt(from);
    return !_isOwnPiece(to) &&
        piece != null &&
        isPremoveShape(piece, from, to);
  }

  /// King-onto-rook or rook-onto-king as a castling move (king two squares),
  /// or `null` if [from] and [to] are not a home-rank king and corner rook.
  NormalMove? _castleMove(Square from, Square to) {
    final a = widget.board.pieceAt(from);
    final b = widget.board.pieceAt(to);
    if (a == null || b == null || a.color != b.color) return null;
    final (king, rook) = switch ((a.role, b.role)) {
      (Role.king, Role.rook) => (from, to),
      (Role.rook, Role.king) => (to, from),
      _ => (null, null),
    };
    if (king == null || rook == null) return null;
    final home = a.color == Side.white ? Rank.first : Rank.eighth;
    if (king != Square.fromCoords(File.e, home) || rook.rank != home) {
      return null;
    }
    if (rook.file != File.a && rook.file != File.h) return null;
    final kingTo = Square.fromCoords(rook.file == File.h ? File.g : File.c, home);
    return NormalMove(from: king, to: kingTo);
  }

  /// Squares to hint for [from]: legal targets, the castling partner, and
  /// during the opponent's turn every premove-shaped square.
  Set<Square> _hintsFor(Square from) {
    final hints = <Square>{...?widget.legalMoves[from]};
    final premoving = widget.canPremove && widget.legalMoves[from] == null;
    for (var i = 0; i < 64; i++) {
      final to = Square(i);
      if (hints.contains(to)) continue;
      final wanted = premoving || (_isOwnPiece(to) && _castleMove(from, to) != null);
      if (wanted && _isTarget(from, to)) hints.add(to);
    }
    return hints;
  }

  Square? _squareAt(Offset local) {
    if (_squareSize <= 0) return null;
    final col = (local.dx / _squareSize).floor();
    final row = (local.dy / _squareSize).floor();
    if (col < 0 || col > 7 || row < 0 || row > 7) return null;
    final white = widget.orientation == Side.white;
    final file = white ? col : 7 - col;
    final rank = white ? 7 - row : row;
    return Square.fromCoords(File(file), Rank(rank));
  }

  void _onTapUp(TapUpDetails details) {
    if (!_interactive) return;
    final square = _squareAt(details.localPosition);
    if (square == null) return;
    final selected = _selected;
    if (selected != null && _isTarget(selected, square)) {
      _submit(selected, square);
      return;
    }
    if (_isOwnPiece(square)) {
      setState(() => _selected = selected == square ? null : square);
      return;
    }
    setState(() => _selected = null);
    widget.onEmptyTap?.call();
  }

  void _onPanStart(DragStartDetails details) {
    if (!_interactive) return;
    final square = _squareAt(details.localPosition);
    if (square == null || !_isOwnPiece(square)) return;
    setState(() {
      _dragFrom = square;
      _selected = square;
      _dragPosition = details.localPosition;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_dragFrom == null) return;
    setState(() => _dragPosition = details.localPosition);
  }

  void _onPanEnd(DragEndDetails details) {
    final from = _dragFrom;
    final position = _dragPosition;
    setState(() {
      _dragFrom = null;
      _dragPosition = null;
    });
    if (from == null || position == null) return;
    final to = _squareAt(position);
    if (to != null && _isTarget(from, to)) {
      _submit(from, to);
    }
  }

  Future<void> _submit(Square from, Square to) async {
    setState(() => _selected = null);
    final castle = _castleMove(from, to);
    if (castle != null) {
      widget.onMove?.call(castle);
      return;
    }
    Role? promotion;
    final isLegalMove = widget.legalMoves[from]?.contains(to) ?? false;
    if (isLegalMove && needsPromotion(widget.board, from, to)) {
      promotion = await _choosePromotion();
      if (promotion == null || !mounted) return;
    }
    widget.onMove?.call(NormalMove(from: from, to: to, promotion: promotion));
  }

  Future<Role?> _choosePromotion() {
    final side = widget.interactiveSide!;
    return showDialog<Role>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Promote to'),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final role in const [Role.queen, Role.rook, Role.bishop, Role.knight])
                InkWell(
                  onTap: () => Navigator.pop(context, role),
                  child: SizedBox.square(
                    dimension: 56,
                    child: CustomPaint(
                      painter: _SinglePiecePainter(
                          _pieces, Piece(color: side, role: role)),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(builder: (context, constraints) {
        _squareSize = constraints.maxWidth / 8;
        final selected = _selected;
        final targets =
            selected == null ? const <Square>{} : _hintsFor(selected);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: _onTapUp,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onPanCancel: () => setState(() {
            _dragFrom = null;
            _dragPosition = null;
          }),
          child: RepaintBoundary(
            child: CustomPaint(
              size: Size.square(constraints.maxWidth),
              painter: _BoardPainter(
                widget: widget,
                pieces: _pieces,
                selected: selected,
                targets: widget.showLegalMoves ? targets : const {},
                dragFrom: _dragFrom,
                dragPosition: _dragPosition,
                textScale: MediaQuery.textScalerOf(context),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _SinglePiecePainter extends CustomPainter {
  _SinglePiecePainter(this.pieces, this.piece);

  final PiecePainter pieces;
  final Piece piece;

  @override
  void paint(Canvas canvas, Size size) =>
      pieces.paint(canvas, piece, Offset.zero & size);

  @override
  bool shouldRepaint(_SinglePiecePainter old) => old.piece != piece;
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.widget,
    required this.pieces,
    required this.selected,
    required this.targets,
    required this.dragFrom,
    required this.dragPosition,
    required this.textScale,
  });

  final ChessBoard widget;
  final PiecePainter pieces;
  final Square? selected;
  final Set<Square> targets;
  final Square? dragFrom;
  final Offset? dragPosition;
  final TextScaler textScale;

  BoardTheme get theme => widget.theme;

  @override
  void paint(Canvas canvas, Size size) {
    final sq = size.width / 8;
    Rect rectOf(Square s) {
      final white = widget.orientation == Side.white;
      final col = white ? s.file : 7 - s.file;
      final row = white ? 7 - s.rank : s.rank;
      return Rect.fromLTWH(col * sq, row * sq, sq, sq);
    }

    // Squares.
    final light = Paint()..color = theme.light;
    final dark = Paint()..color = theme.dark;
    for (var i = 0; i < 64; i++) {
      final s = Square(i);
      final isLight = (s.file + s.rank).isOdd;
      canvas.drawRect(rectOf(s), isLight ? light : dark);
    }
    if (theme.gloss) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white.withValues(alpha: 0.28), Colors.white.withValues(alpha: 0.0), Colors.white.withValues(alpha: 0.10)],
            stops: const [0, 0.55, 1],
          ).createShader(Offset.zero & size),
      );
    }

    // Highlights.
    final lastMove = widget.lastMove;
    if (widget.highlightLastMove && lastMove != null) {
      final paint = Paint()..color = theme.lastMove;
      canvas.drawRect(rectOf(lastMove.$1), paint);
      canvas.drawRect(rectOf(lastMove.$2), paint);
    }
    final premovePaint = Paint()..color = theme.premove;
    for (final m in widget.premoves) {
      canvas.drawRect(rectOf(m.from), premovePaint);
      canvas.drawRect(rectOf(m.to), premovePaint);
    }
    if (selected != null) {
      canvas.drawRect(rectOf(selected!), Paint()..color = theme.selected);
    }
    final check = widget.checkSquare;
    if (check != null) {
      final r = rectOf(check);
      canvas.drawRect(
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [theme.check, theme.check.withValues(alpha: 0)],
          ).createShader(r),
      );
    }

    if (widget.showCoordinates) _paintCoordinates(canvas, sq);

    // Pieces.
    for (final (square, piece) in widget.board.pieces) {
      if (square == dragFrom) continue;
      pieces.paint(canvas, piece, rectOf(square));
    }

    // Move hints.
    final hint = Paint()..color = theme.moveHint;
    for (final t in targets) {
      final r = rectOf(t);
      if (widget.board.pieceAt(t) != null) {
        canvas.drawCircle(
          r.center,
          sq * 0.44,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = sq * 0.08
            ..color = theme.moveHint,
        );
      } else {
        canvas.drawCircle(r.center, sq * 0.16, hint);
      }
    }

    for (final arrow in widget.arrows) {
      _paintArrow(canvas, rectOf(arrow.from).center, rectOf(arrow.to).center,
          arrow.color, sq);
    }

    final badge = widget.badge;
    if (badge != null) _paintBadge(canvas, rectOf(badge.$1), badge.$2, sq);

    // Dragged piece floats above everything, slightly enlarged.
    final from = dragFrom;
    final pos = dragPosition;
    if (from != null && pos != null) {
      final piece = widget.board.pieceAt(from);
      if (piece != null) {
        final big = sq * 1.25;
        pieces.paint(canvas, piece,
            Rect.fromCenter(center: pos, width: big, height: big));
      }
    }
  }

  void _paintCoordinates(Canvas canvas, double sq) {
    final white = widget.orientation == Side.white;
    final fontSize = textScale.scale(sq * 0.18);
    for (var i = 0; i < 8; i++) {
      // Files along the bottom row, ranks along the left column.
      final file = white ? i : 7 - i;
      final rank = white ? 7 - i : i;
      final bottomIsLight = (file + (white ? 0 : 7)).isOdd;
      final leftIsLight = ((white ? 0 : 7) + rank).isOdd;
      _text(canvas, File(file).name, Offset((i + 1) * sq - sq * 0.16, 8 * sq - sq * 0.24),
          bottomIsLight ? theme.dark : theme.light, fontSize);
      _text(canvas, Rank(rank).name, Offset(sq * 0.06, i * sq + sq * 0.04),
          leftIsLight ? theme.dark : theme.light, fontSize);
    }
  }

  void _text(Canvas canvas, String text, Offset at, Color color, double size) {
    TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )
      ..layout()
      ..paint(canvas, at);
  }

  void _paintArrow(Canvas canvas, Offset from, Offset to, Color color, double sq) {
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    final head = sq * 0.42;
    final shaftEnd = to - Offset(math.cos(angle), math.sin(angle)) * head * 0.8;
    canvas.drawLine(
      from,
      shaftEnd,
      Paint()
        ..color = color
        ..strokeWidth = sq * 0.17
        ..strokeCap = StrokeCap.round,
    );
    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(to.dx - head * math.cos(angle - 0.5), to.dy - head * math.sin(angle - 0.5))
      ..lineTo(to.dx - head * math.cos(angle + 0.5), to.dy - head * math.sin(angle + 0.5))
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _paintBadge(Canvas canvas, Rect square, MoveClass cls, double sq) {
    final radius = sq * 0.2;
    final center = Offset(square.right - radius * 0.6, square.top + radius * 0.6);
    canvas.drawCircle(center + const Offset(0, 1.5), radius,
        Paint()..color = Colors.black26);
    canvas.drawCircle(center, radius, Paint()..color = cls.color);
    final painter = TextPainter(
      text: TextSpan(
        text: cls.badge,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 1.05,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(_BoardPainter old) =>
      old.widget != widget ||
      old.pieces != pieces ||
      old.selected != selected ||
      old.targets != targets ||
      old.dragFrom != dragFrom ||
      old.dragPosition != dragPosition;
}
