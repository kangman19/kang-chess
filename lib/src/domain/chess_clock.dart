import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';

import 'time_control.dart';

/// Returns monotonic elapsed time. Injected in tests.
typedef MonotonicNow = Duration Function();

final Stopwatch _monotonic = Stopwatch()..start();
Duration _defaultNow() => _monotonic.elapsed;

/// Two-sided chess clock with Fischer increment.
///
/// Time is measured from a monotonic stopwatch; the periodic ticker only
/// refreshes listeners and detects flag fall. The clock is its own listenable
/// so ticks rebuild clock widgets only.
class ChessClock extends ChangeNotifier {
  ChessClock(
    this.setup, {
    MonotonicNow? now,
    this.onFlag,
    this.tickInterval = const Duration(milliseconds: 100),
    this.autoTick = true,
  })  : _now = now ?? _defaultNow,
        _remaining = {
          Side.white: setup.white?.initial ?? Duration.zero,
          Side.black: setup.black?.initial ?? Duration.zero,
        };

  final ClockSetup setup;
  final void Function(Side flagged)? onFlag;
  final Duration tickInterval;
  /// Whether a periodic timer drives [tick]. Tests drive it manually.
  final bool autoTick;
  final MonotonicNow _now;
  final Map<Side, Duration> _remaining;

  Side? _running;
  Duration _runningSince = Duration.zero;
  Side? _flagged;
  Timer? _ticker;
  bool _disposed = false;

  bool get isTimed => setup.isTimed;
  Side? get running => _running;
  Side? get flagged => _flagged;

  Duration remaining(Side side) {
    final base = _remaining[side]!;
    if (side != _running) return base;
    final left = base - (_now() - _runningSince);
    return left.isNegative ? Duration.zero : left;
  }

  /// Starts [side]'s clock. No-op when untimed or after a flag.
  void start(Side side) {
    if (!isTimed || _flagged != null || _disposed) return;
    _commitRunning();
    _running = side;
    _runningSince = _now();
    if (autoTick) {
      _ticker ??= Timer.periodic(tickInterval, (_) => tick());
    }
    notifyListeners();
  }

  /// Records a completed move by [mover]: charges elapsed time, adds the
  /// increment, then starts the opponent's clock.
  void moveMade(Side mover) {
    if (!isTimed || _flagged != null || _disposed) return;
    if (_running == mover) _commitRunning();
    if (_checkFlag(mover)) return;
    _remaining[mover] = _remaining[mover]! + setup.of(mover)!.increment;
    start(mover.opposite);
  }

  /// Stops both clocks, keeping remaining times.
  void stop() {
    _commitRunning();
    _running = null;
    _ticker?.cancel();
    _ticker = null;
    if (!_disposed) notifyListeners();
  }

  /// Checks for flag fall and refreshes listeners.
  @visibleForTesting
  void tick() {
    if (_disposed) return;
    final side = _running;
    if (side != null && remaining(side) == Duration.zero) {
      _commitRunning();
      _checkFlag(side);
      return;
    }
    notifyListeners();
  }

  bool _checkFlag(Side side) {
    if (_remaining[side]! > Duration.zero) return false;
    _remaining[side] = Duration.zero;
    _flagged = side;
    stop();
    onFlag?.call(side);
    return true;
  }

  void _commitRunning() {
    final side = _running;
    if (side == null) return;
    final now = _now();
    final left = _remaining[side]! - (now - _runningSince);
    _remaining[side] = left.isNegative ? Duration.zero : left;
    _runningSince = now;
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _ticker = null;
    super.dispose();
  }
}

/// Formats a clock reading; shows tenths below 20 seconds.
String formatClock(Duration d) {
  if (d < const Duration(seconds: 20)) {
    final tenths = (d.inMilliseconds % 1000) ~/ 100;
    return '0:${d.inSeconds.toString().padLeft(2, '0')}.$tenths';
  }
  final hours = d.inHours;
  final minutes = d.inMinutes % 60;
  final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
  return hours > 0
      ? '$hours:${minutes.toString().padLeft(2, '0')}:$seconds'
      : '$minutes:$seconds';
}
