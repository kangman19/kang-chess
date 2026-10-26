import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:kang_chess/src/core/chess_utils.dart';
import 'package:kang_chess/src/engine/engine_service.dart';

/// Scripted UCI engine. By default answers each `go` with the first legal
/// move of the current position. Searches can be held open to test `stop`.
class FakeUciTransport implements UciTransport {
  FakeUciTransport({this.holdSearches = false, this.chooser});

  bool holdSearches;

  /// Picks `(bestmove, info lines)` for a position; defaults to first legal.
  final (String?, List<String>) Function(Position position)? chooser;

  final _lines = StreamController<String>.broadcast();
  final List<String> sent = [];
  Position _position = Chess.initial;
  bool _searching = false;
  bool started = false;
  bool disposed = false;
  int goCount = 0;

  @override
  Stream<String> get lines => _lines.stream;

  @override
  Future<void> start() async => started = true;

  @override
  void send(String command) {
    sent.add(command);
    if (command == 'uci') {
      _emit('id name Fake');
      _emit('uciok');
    } else if (command == 'isready') {
      _emit('readyok');
    } else if (command.startsWith('position fen ')) {
      _position = _parsePosition(command);
    } else if (command.startsWith('go')) {
      goCount++;
      _searching = true;
      if (!holdSearches) scheduleMicrotask(_finishSearch);
    } else if (command == 'stop') {
      if (_searching) scheduleMicrotask(_finishSearch);
    }
  }

  /// Completes a held search.
  void release() => _finishSearch();

  void _finishSearch() {
    if (!_searching) return;
    _searching = false;
    final (best, info) = (chooser ?? _firstLegal)(_position);
    for (final line in info) {
      _emit(line);
    }
    _emit('bestmove ${best ?? '(none)'}');
  }

  static (String?, List<String>) _firstLegal(Position pos) {
    final moves = allLegalMoves(pos);
    if (moves.isEmpty) return (null, const []);
    final uci = toStandardUci(pos, moves.first);
    return (uci, ['info depth 1 multipv 1 score cp 0 pv $uci']);
  }

  Position _parsePosition(String command) {
    final rest = command.substring('position fen '.length);
    final parts = rest.split(' moves ');
    var pos = Chess.fromSetup(Setup.parseFen(parts.first)) as Position;
    if (parts.length > 1) {
      for (final uci in parts[1].trim().split(' ')) {
        pos = pos.play(parseLegalUci(pos, uci)!);
      }
    }
    return pos;
  }

  void _emit(String line) {
    if (!_lines.isClosed) _lines.add(line);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _lines.close();
  }
}
