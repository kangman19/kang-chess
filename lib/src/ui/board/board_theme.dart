import 'package:flutter/material.dart';

/// Board colorway. Highlights are drawn translucently over the squares.
class BoardTheme {
  const BoardTheme({
    required this.id,
    required this.name,
    required this.light,
    required this.dark,
    required this.lastMove,
    required this.selected,
    required this.premove,
    required this.moveHint,
    required this.check,
    this.gloss = false,
  });

  final String id;
  final String name;
  final Color light;
  final Color dark;
  final Color lastMove;
  final Color selected;
  final Color premove;
  final Color moveHint;
  final Color check;

  /// Draws a soft glass reflection over the board.
  final bool gloss;

  static const classicWood = BoardTheme(
    id: 'wood',
    name: 'Classic Wood',
    light: Color(0xFFE8CBA0),
    dark: Color(0xFFAE7646),
    lastMove: Color(0x80E6D24C),
    selected: Color(0x9944A05A),
    premove: Color(0x99C05A3C),
    moveHint: Color(0x55302010),
    check: Color(0xCCE53935),
  );

  static const tournamentGreen = BoardTheme(
    id: 'green',
    name: 'Tournament Green',
    light: Color(0xFFE6E9C6),
    dark: Color(0xFF6F9A57),
    lastMove: Color(0x80F2E25E),
    selected: Color(0x99B8D64A),
    premove: Color(0x99D2553F),
    moveHint: Color(0x55203018),
    check: Color(0xCCE53935),
  );

  static const modernCharcoal = BoardTheme(
    id: 'charcoal',
    name: 'Modern Charcoal',
    light: Color(0xFFA7ADB6),
    dark: Color(0xFF4A515C),
    lastMove: Color(0x8090CAF9),
    selected: Color(0x9964B5F6),
    premove: Color(0x99FF8A65),
    moveHint: Color(0x66101418),
    check: Color(0xCCFF5252),
  );

  static const neonNight = BoardTheme(
    id: 'neon',
    name: 'Neon Night',
    light: Color(0xFF39335E),
    dark: Color(0xFF1A1631),
    lastMove: Color(0x8000E5FF),
    selected: Color(0x99FF4FD8),
    premove: Color(0x99FFB300),
    moveHint: Color(0x8800E5FF),
    check: Color(0xCCFF1744),
  );

  static const glassBlue = BoardTheme(
    id: 'glass',
    name: 'Glass Blue',
    light: Color(0xFFDCEBFA),
    dark: Color(0xFF7FA7D1),
    lastMove: Color(0x80FFF59D),
    selected: Color(0x9940C4FF),
    premove: Color(0x99F06292),
    moveHint: Color(0x5513324F),
    check: Color(0xCCE53935),
    gloss: true,
  );

  static const sunsetCoral = BoardTheme(
    id: 'coral',
    name: 'Sunset Coral',
    light: Color(0xFFF6DCCB),
    dark: Color(0xFFC77D63),
    lastMove: Color(0x80FFE082),
    selected: Color(0x99FFAB40),
    premove: Color(0x997E57C2),
    moveHint: Color(0x553A1A10),
    check: Color(0xCCD32F2F),
  );

  static const all = [
    classicWood,
    tournamentGreen,
    modernCharcoal,
    neonNight,
    glassBlue,
    sunsetCoral,
  ];

  static BoardTheme byId(String? id) =>
      all.firstWhere((t) => t.id == id, orElse: () => tournamentGreen);
}
