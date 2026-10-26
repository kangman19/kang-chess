import 'dart:async';

import 'package:stockfish_chess_engine/stockfish_chess_engine.dart';

import 'engine_service.dart';

/// Embedded Stockfish over FFI. The plugin allows one instance per process.
class StockfishTransport implements UciTransport {
  final _lines = StreamController<String>.broadcast();
  Stockfish? _stockfish;
  StreamSubscription<String>? _stdout;

  @override
  Stream<String> get lines => _lines.stream;

  @override
  Future<void> start() async {
    final stockfish = await stockfishAsync();
    _stockfish = stockfish;
    _stdout = stockfish.stdout.listen(_lines.add);
  }

  @override
  void send(String command) {
    final stockfish = _stockfish;
    if (stockfish == null) throw StateError('Stockfish is not started');
    stockfish.stdin = command;
  }

  @override
  Future<void> dispose() async {
    await _stdout?.cancel();
    _stdout = null;
    _stockfish?.dispose();
    _stockfish = null;
    await _lines.close();
  }
}
