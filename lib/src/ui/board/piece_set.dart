import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

/// Switchable piece art. Every set is drawn by our own code.
enum PieceSet {
  glyph('Classic Glyph'),
  geometric('Geometric'),
  letters('Letters'),
  neon('Neon Glyph');

  const PieceSet(this.label);
  final String label;

  static PieceSet byName(String? name) =>
      values.firstWhere((s) => s.name == name, orElse: () => glyph);
}

/// Paints pieces, caching laid-out text per (set, piece, size).
class PiecePainter {
  PiecePainter(this.set);

  final PieceSet set;
  final Map<(Piece, int), (TextPainter, TextPainter?)> _textCache = {};

  void paint(Canvas canvas, Piece piece, Rect rect) {
    switch (set) {
      case PieceSet.glyph:
      case PieceSet.neon:
      case PieceSet.letters:
        _paintText(canvas, piece, rect);
      case PieceSet.geometric:
        _paintGeometric(canvas, piece, rect);
    }
  }

  // Solid chess glyphs with U+FE0E so platforms render text, not emoji.
  // The pawn (U+265F) is an emoji on Android and ignores VS15 there, drawing
  // as a fixed black emoji for both sides, so it is painted as a path instead.
  static const _glyphs = {
    Role.king: '♚︎',
    Role.queen: '♛︎',
    Role.rook: '♜︎',
    Role.bishop: '♝︎',
    Role.knight: '♞︎',
  };

  void _paintText(Canvas canvas, Piece piece, Rect rect) {
    if (piece.role == Role.pawn && set != PieceSet.letters) {
      _paintGlyphPawn(canvas, piece, rect);
      return;
    }
    final size = rect.width.round();
    final (stroke, fill) =
        _textCache.putIfAbsent((piece, size), () => _layoutText(piece, size));
    if (set == PieceSet.letters) _paintToken(canvas, piece, rect);
    final offset = rect.center - Offset(stroke.width / 2, stroke.height / 2);
    stroke.paint(canvas, offset);
    fill?.paint(canvas, offset);
  }

  (TextPainter, TextPainter?) _layoutText(Piece piece, int size) {
    final white = piece.color == Side.white;
    if (set == PieceSet.letters) {
      final letter = TextPainter(
        text: TextSpan(
          text: piece.role.uppercaseLetter,
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.w800,
            color: white ? const Color(0xFF263238) : const Color(0xFFF5F5F5),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return (letter, null);
    }

    final glyph = _glyphs[piece.role]!;
    final (outline, fillColor) = _glyphPaints(piece, size.toDouble());
    TextPainter make(TextStyle style) => TextPainter(
          text: TextSpan(text: glyph, style: style),
          textDirection: TextDirection.ltr,
        )..layout();
    final base = TextStyle(fontSize: size * 0.8, height: 1.0);
    return (
      make(base.copyWith(foreground: outline)),
      make(base.copyWith(color: fillColor)),
    );
  }

  /// Outline paint and fill color shared by the glyph and neon sets.
  (Paint, Color) _glyphPaints(Piece piece, double size) {
    final white = piece.color == Side.white;
    final neon = set == PieceSet.neon;
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * (neon ? 0.05 : 0.045)
      ..strokeJoin = StrokeJoin.round
      ..color = neon
          ? (white ? const Color(0xFF00E5FF) : const Color(0xFFFF4FD8))
          : (white ? const Color(0xFF1B1B1B) : const Color(0xFFE0E0E0));
    if (neon) {
      outline.maskFilter = MaskFilter.blur(BlurStyle.solid, size * 0.03);
    }
    final fillColor = neon
        ? (white ? const Color(0xFFE0FCFF) : const Color(0xFF2A0E2E))
        : (white ? const Color(0xFFFAFAFA) : const Color(0xFF262626));
    return (outline, fillColor);
  }

  /// Glyph-style pawn silhouette on a 100×100 grid, sized like the glyphs.
  void _paintGlyphPawn(Canvas canvas, Piece piece, Rect rect) {
    final (outline, fillColor) = _glyphPaints(piece, 100);
    canvas.save();
    canvas.translate(rect.left, rect.top);
    canvas.scale(rect.width / 100);
    final path = Path()
      ..addOval(Rect.fromCircle(center: const Offset(50, 33), radius: 11))
      ..addRRect(RRect.fromLTRBR(37, 44, 63, 51, const Radius.circular(3.5)))
      ..moveTo(43, 51)
      ..quadraticBezierTo(44, 64, 33, 74)
      ..lineTo(67, 74)
      ..quadraticBezierTo(56, 64, 57, 51)
      ..close()
      ..addRRect(RRect.fromLTRBR(28, 73, 72, 81, const Radius.circular(4)));
    canvas.drawPath(path, outline);
    canvas.drawPath(path, Paint()..color = fillColor);
    canvas.restore();
  }

  void _paintToken(Canvas canvas, Piece piece, Rect rect) {
    final white = piece.color == Side.white;
    final radius = rect.width * 0.38;
    canvas.drawCircle(
      rect.center,
      radius,
      Paint()..color = white ? const Color(0xFFF5F5F5) : const Color(0xFF263238),
    );
    canvas.drawCircle(
      rect.center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rect.width * 0.04
        ..color = white ? const Color(0xFF263238) : const Color(0xFFB0BEC5),
    );
  }

  /// Original vector silhouettes on a 100×100 grid.
  void _paintGeometric(Canvas canvas, Piece piece, Rect rect) {
    final white = piece.color == Side.white;
    canvas.save();
    canvas.translate(rect.left, rect.top);
    canvas.scale(rect.width / 100);
    final fill = Paint()
      ..color = white ? const Color(0xFFF7F4EE) : const Color(0xFF2B2B2B);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeJoin = StrokeJoin.round
      ..color = white ? const Color(0xFF222222) : const Color(0xFFEDEDED);
    final detail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = white ? const Color(0xFF222222) : const Color(0xFFEDEDED);

    final path = Path();
    void base() => path.addRRect(RRect.fromLTRBR(22, 78, 78, 89, const Radius.circular(4)));
    void poly(List<Offset> points) => path.addPolygon(points, true);

    switch (piece.role) {
      case Role.pawn:
        base();
        poly(const [Offset(38, 50), Offset(62, 50), Offset(69, 78), Offset(31, 78)]);
        path.addOval(Rect.fromCircle(center: const Offset(50, 37), radius: 13));
      case Role.rook:
        base();
        path.addRect(const Rect.fromLTRB(33, 42, 67, 78));
        path.addRect(const Rect.fromLTRB(27, 30, 73, 42));
        for (final x in const [27.0, 44.0, 61.0]) {
          path.addRect(Rect.fromLTWH(x, 18, 12, 12));
        }
      case Role.bishop:
        base();
        poly(const [Offset(40, 60), Offset(60, 60), Offset(66, 78), Offset(34, 78)]);
        path.addOval(Rect.fromCenter(center: const Offset(50, 42), width: 32, height: 40));
        path.addOval(Rect.fromCircle(center: const Offset(50, 17), radius: 6));
      case Role.knight:
        base();
        poly(const [
          Offset(30, 78), Offset(34, 58), Offset(28, 48), Offset(31, 33),
          Offset(44, 18), Offset(52, 12), Offset(56, 20), Offset(72, 38),
          Offset(73, 50), Offset(62, 50), Offset(54, 46), Offset(58, 60),
          Offset(68, 78),
        ]);
      case Role.queen:
        base();
        poly(const [
          Offset(22, 30), Offset(34, 56), Offset(40, 24), Offset(50, 52),
          Offset(60, 24), Offset(66, 56), Offset(78, 30), Offset(70, 78),
          Offset(30, 78),
        ]);
        for (final c in const [Offset(22, 26), Offset(40, 20), Offset(60, 20), Offset(78, 26)]) {
          path.addOval(Rect.fromCircle(center: c, radius: 5));
        }
      case Role.king:
        base();
        poly(const [Offset(32, 48), Offset(68, 48), Offset(71, 78), Offset(29, 78)]);
        path.addOval(Rect.fromCenter(center: const Offset(50, 46), width: 44, height: 22));
        path.addRect(const Rect.fromLTRB(46, 8, 54, 36));
        path.addRect(const Rect.fromLTRB(38, 15, 62, 23));
    }

    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
    switch (piece.role) {
      case Role.bishop:
        canvas.drawLine(const Offset(46, 34), const Offset(56, 44), detail);
      case Role.knight:
        canvas.drawCircle(const Offset(52, 28), 2.5, detail..style = PaintingStyle.fill);
      case Role.queen:
      case Role.king:
        canvas.drawLine(const Offset(32, 64), const Offset(68, 64), detail);
      default:
        break;
    }
    canvas.restore();
  }
}
