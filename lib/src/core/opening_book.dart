/// A compact opening book of well-known main lines, in standard UCI.
///
/// A move is "Book" when the game so far is a prefix of one of these lines.
/// Opening move orders are common chess knowledge; the list is ours.
class OpeningBook {
  OpeningBook._();

  static const maxBookPly = 20;

  static const List<String> _lines = [
    // 1.e4 e5
    'e2e4 e7e5 g1f3 b8c6 f1c4 f8c5 c2c3 g8f6 d2d3 d7d6',
    'e2e4 e7e5 g1f3 b8c6 f1c4 g8f6 d2d3 f8e7 e1g1 e8g8',
    'e2e4 e7e5 g1f3 b8c6 f1b5 a7a6 b5a4 g8f6 e1g1 f8e7 f1e1 b7b5',
    'e2e4 e7e5 g1f3 b8c6 f1b5 g8f6 e1g1 f6e4 d2d4 e4d6',
    'e2e4 e7e5 g1f3 b8c6 d2d4 e5d4 f3d4 g8f6 d4c6 b7c6',
    'e2e4 e7e5 g1f3 g8f6 f3e5 d7d6 e5f3 f6e4 d2d4 d6d5',
    'e2e4 e7e5 g1f3 d7d6 d2d4 g8f6 b1c3 b8d7',
    'e2e4 e7e5 b1c3 g8f6 f2f4 d7d5',
    'e2e4 e7e5 f2f4 e5f4 g1f3 g7g5',
    // Sicilian
    'e2e4 c7c5 g1f3 d7d6 d2d4 c5d4 f3d4 g8f6 b1c3 a7a6',
    'e2e4 c7c5 g1f3 d7d6 d2d4 c5d4 f3d4 g8f6 b1c3 g7g6',
    'e2e4 c7c5 g1f3 b8c6 d2d4 c5d4 f3d4 g8f6 b1c3 e7e5',
    'e2e4 c7c5 g1f3 e7e6 d2d4 c5d4 f3d4 a7a6',
    'e2e4 c7c5 c2c3 g8f6 e4e5 f6d5 d2d4 c5d4',
    'e2e4 c7c5 b1c3 b8c6 g2g3 g7g6',
    // French, Caro-Kann, others
    'e2e4 e7e6 d2d4 d7d5 b1c3 g8f6 c1g5 f8e7',
    'e2e4 e7e6 d2d4 d7d5 e4e5 c7c5 c2c3 b8c6',
    'e2e4 e7e6 d2d4 d7d5 b1d2 c7c5',
    'e2e4 c7c6 d2d4 d7d5 b1c3 d5e4 c3e4 c8f5',
    'e2e4 c7c6 d2d4 d7d5 e4e5 c8f5 g1f3 e7e6',
    'e2e4 d7d5 e4d5 d8d5 b1c3 d5a5 d2d4 g8f6',
    'e2e4 d7d6 d2d4 g8f6 b1c3 g7g6 g1f3 f8g7',
    'e2e4 g7g6 d2d4 f8g7 b1c3 d7d6',
    // 1.d4
    'd2d4 d7d5 c2c4 e7e6 b1c3 g8f6 c1g5 f8e7',
    'd2d4 d7d5 c2c4 d5c4 g1f3 g8f6 e2e3 e7e6',
    'd2d4 d7d5 c2c4 c7c6 g1f3 g8f6 b1c3 d5c4',
    'd2d4 d7d5 c1f4 g8f6 e2e3 e7e6 g1f3 c7c5',
    'd2d4 d7d5 g1f3 g8f6 c1f4 c7c5 e2e3',
    'd2d4 g8f6 c1f4 e7e6 e2e3 c7c5',
    'd2d4 g8f6 c2c4 g7g6 b1c3 f8g7 e2e4 d7d6 g1f3 e8g8',
    'd2d4 g8f6 c2c4 g7g6 b1c3 d7d5 c4d5 f6d5',
    'd2d4 g8f6 c2c4 e7e6 b1c3 f8b4 e2e3 e8g8',
    'd2d4 g8f6 c2c4 e7e6 g1f3 b7b6 g2g3',
    'd2d4 g8f6 c2c4 c7c5 d4d5 e7e6',
    'd2d4 f7f5 g2g3 g8f6 f1g2 e7e6',
    // Flank openings
    'c2c4 e7e5 b1c3 g8f6 g1f3 b8c6 g2g3',
    'c2c4 g8f6 b1c3 e7e6 e2e4',
    'g1f3 d7d5 c2c4 e7e6 g2g3 g8f6',
    'g1f3 g8f6 g2g3 g7g6 f1g2 f8g7',
  ];

  static final Set<String> _prefixes = {
    for (final line in _lines)
      for (var i = 1; i <= line.split(' ').length; i++)
        line.split(' ').take(i).join(' '),
  };

  /// Whether the sequence of standard-UCI [moves] is a book prefix.
  static bool contains(List<String> moves) =>
      moves.isNotEmpty &&
      moves.length <= maxBookPly &&
      _prefixes.contains(moves.join(' '));
}
