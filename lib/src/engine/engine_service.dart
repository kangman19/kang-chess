import 'dart:async';

import 'uci.dart';

/// Line-oriented connection to a UCI engine.
abstract interface class UciTransport {
  Future<void> start();
  Stream<String> get lines;
  void send(String command);
  Future<void> dispose();
}

/// Cooperative cancellation for a queued or running search.
class CancelToken {
  bool _cancelled = false;
  void Function()? _onCancel;

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _onCancel?.call();
  }
}

class EngineOptions {
  const EngineOptions({this.multiPv = 1, this.limitElo});

  final int multiPv;

  /// Enables `UCI_LimitStrength` at this Elo; `null` plays at full strength.
  final int? limitElo;
}

class SearchRequest {
  const SearchRequest({
    required this.startFen,
    this.moves = const [],
    this.options = const EngineOptions(),
    this.depth,
    this.movetime,
  }) : assert(depth != null || movetime != null);

  final String startFen;

  /// Moves from [startFen], standard UCI, so the engine sees repetitions.
  final List<String> moves;
  final EngineOptions options;
  final int? depth;
  final Duration? movetime;
}

class SearchResult {
  const SearchResult({required this.bestMove, required this.lines});

  static const empty = SearchResult(bestMove: null, lines: []);

  final String? bestMove;

  /// Final lines ordered by MultiPV rank.
  final List<PvLine> lines;

  PvLine? get best => lines.isEmpty ? null : lines.first;
  PvLine? get second => lines.length > 1 ? lines[1] : null;
}

/// Serializes searches over one UCI engine instance.
///
/// Each search is `setoption…` → `isready` → `position` → `go` → `bestmove`.
/// Cancelling sends `stop` and still waits for `bestmove`, so the next job
/// never reads output from a stale search. One stdout subscription serves the
/// engine's whole lifetime.
class EngineService {
  EngineService(this._transport, {this.threads = 1, this.hashMb = 32});

  static const minUciElo = 1320;
  static const maxUciElo = 3190;
  static const _readyTimeout = Duration(seconds: 15);

  final UciTransport _transport;
  final int threads;
  final int hashMb;

  final Map<String, String> _sentOptions = {};
  Future<void>? _startup;
  StreamSubscription<String>? _subscription;
  void Function(String line)? _handler;
  Future<void> _tail = Future.value();
  Completer<void>? _pendingWait;
  bool _searching = false;
  bool _disposed = false;

  bool get isDisposed => _disposed;

  /// Queues a search. Completes with [SearchResult.empty] when cancelled
  /// before it starts.
  Future<SearchResult> search(
    SearchRequest request, {
    CancelToken? cancel,
    void Function(List<PvLine> lines)? onUpdate,
  }) {
    if (_disposed) {
      return Future.error(StateError('Engine has been disposed'));
    }
    final job = _tail.then((_) => _run(request, cancel, onUpdate));
    _tail = job.then((_) {}, onError: (_) {});
    return job;
  }

  Future<void> _ensureStarted() => _startup ??= _start();

  Future<void> _start() async {
    await _transport.start();
    _subscription = _transport.lines.listen((line) => _handler?.call(line));
    _transport.send('uci');
    await _waitFor('uciok');
    _setOption('Threads', '$threads');
    _setOption('Hash', '$hashMb');
  }

  Future<SearchResult> _run(
    SearchRequest request,
    CancelToken? cancel,
    void Function(List<PvLine>)? onUpdate,
  ) async {
    bool abandoned() => _disposed || (cancel?.isCancelled ?? false);

    if (abandoned()) return SearchResult.empty;
    await _ensureStarted();
    if (abandoned()) return SearchResult.empty;

    final options = request.options;
    _setOption('MultiPV', '${options.multiPv}');
    final elo = options.limitElo;
    _setOption('UCI_LimitStrength', elo != null ? 'true' : 'false');
    if (elo != null) {
      _setOption('UCI_Elo', '${elo.clamp(minUciElo, maxUciElo)}');
    }
    _transport.send('isready');
    await _waitFor('readyok');
    if (abandoned()) return SearchResult.empty;

    final position = request.moves.isEmpty
        ? 'position fen ${request.startFen}'
        : 'position fen ${request.startFen} moves ${request.moves.join(' ')}';
    _transport.send(position);

    final lines = <int, PvLine>{};
    final done = Completer<SearchResult>();
    _handler = (line) {
      if (line.startsWith('info')) {
        final pv = parseInfoLine(line);
        if (pv == null || pv.multipv > options.multiPv) return;
        lines[pv.multipv] = pv;
        if (onUpdate != null && pv.multipv == 1) onUpdate(_ordered(lines));
        return;
      }
      final best = parseBestMove(line);
      if (best.isBestMove && !done.isCompleted) {
        done.complete(
            SearchResult(bestMove: best.move, lines: _ordered(lines)));
      }
    };

    final go = StringBuffer('go');
    if (request.depth != null) go.write(' depth ${request.depth}');
    if (request.movetime != null) {
      go.write(' movetime ${request.movetime!.inMilliseconds}');
    }
    _searching = true;
    cancel?._onCancel = _stopSearch;
    _transport.send(go.toString());

    try {
      return await done.future;
    } finally {
      _searching = false;
      _handler = null;
      cancel?._onCancel = null;
    }
  }

  void _stopSearch() {
    if (_searching) _transport.send('stop');
  }

  List<PvLine> _ordered(Map<int, PvLine> lines) =>
      (lines.keys.toList()..sort()).map((k) => lines[k]!).toList();

  void _setOption(String name, String value) {
    if (_sentOptions[name] == value) return;
    _sentOptions[name] = value;
    _transport.send('setoption name $name value $value');
  }

  /// Waits for a handshake reply. [dispose] releases the wait early.
  Future<void> _waitFor(String token) {
    final ready = _pendingWait = Completer<void>();
    _handler = (line) {
      if (line.trim() == token && !ready.isCompleted) ready.complete();
    };
    return ready.future.timeout(_readyTimeout).whenComplete(() {
      _handler = null;
      _pendingWait = null;
    });
  }

  /// Stops any running search, waits for queued work to drain, and releases
  /// the engine. Safe to call more than once.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _stopSearch();
    final wait = _pendingWait;
    if (wait != null && !wait.isCompleted) wait.complete();
    try {
      await _tail.timeout(const Duration(seconds: 3));
    } on TimeoutException {
      // The engine stopped responding; release it anyway.
    }
    await _subscription?.cancel();
    _subscription = null;
    // The service owns the transport, started or not.
    await _transport.dispose();
  }
}
