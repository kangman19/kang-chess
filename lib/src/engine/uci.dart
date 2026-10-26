import '../domain/score.dart';

/// One principal variation reported by a UCI `info` line.
class PvLine {
  const PvLine({
    required this.multipv,
    required this.depth,
    required this.score,
    required this.moves,
  });

  final int multipv;
  final int depth;

  /// Score from the side to move's point of view.
  final Score score;

  /// Principal variation in standard UCI.
  final List<String> moves;

  String? get firstMove => moves.isEmpty ? null : moves.first;
}

/// Parses an `info ... score ... pv ...` line.
///
/// Returns `null` for lines without a score and PV, and for bound-only scores
/// (`lowerbound`/`upperbound`), which are not final for their depth.
PvLine? parseInfoLine(String line) {
  final tokens = line.trim().split(RegExp(r'\s+'));
  if (tokens.isEmpty || tokens.first != 'info') return null;
  int? depth;
  var multipv = 1;
  Score? score;
  List<String>? pv;
  for (var i = 1; i < tokens.length; i++) {
    switch (tokens[i]) {
      case 'depth':
        depth = int.tryParse(_at(tokens, ++i));
      case 'multipv':
        multipv = int.tryParse(_at(tokens, ++i)) ?? 1;
      case 'score':
        final kind = _at(tokens, ++i);
        final value = int.tryParse(_at(tokens, ++i));
        if (value == null) return null;
        score = kind == 'mate' ? Score.mate(value) : Score.cp(value);
        final next = _at(tokens, i + 1);
        if (next == 'lowerbound' || next == 'upperbound') return null;
      case 'pv':
        pv = tokens.sublist(i + 1);
        i = tokens.length;
      case 'string':
        return null;
    }
  }
  if (depth == null || score == null || pv == null || pv.isEmpty) return null;
  return PvLine(multipv: multipv, depth: depth, score: score, moves: pv);
}

/// Parses `bestmove <uci> [ponder <uci>]`.
///
/// Returns `(isBestMove: false)` for other lines; `move` is `null` for
/// `bestmove (none)`.
({bool isBestMove, String? move}) parseBestMove(String line) {
  final tokens = line.trim().split(RegExp(r'\s+'));
  if (tokens.isEmpty || tokens.first != 'bestmove') {
    return (isBestMove: false, move: null);
  }
  final move = tokens.length > 1 ? tokens[1] : null;
  return (isBestMove: true, move: move == '(none)' ? null : move);
}

String _at(List<String> tokens, int i) => i < tokens.length ? tokens[i] : '';
