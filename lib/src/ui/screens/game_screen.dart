import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../app.dart';
import '../../domain/bot_profile.dart';
import '../../domain/chess_clock.dart';
import '../../domain/time_control.dart';
import '../../game/game_controller.dart';
import '../../settings/settings_controller.dart';
import '../board/chess_board.dart';
import '../bot_avatar.dart';
import 'review_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.bot,
    required this.playerSide,
    required this.clockSetup,
  });

  final BotProfile bot;
  final Side playerSide;
  final ClockSetup clockSetup;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameController _game;
  late Side _orientation = widget.playerSide;
  bool _initialized = false;
  bool _resultShown = false;
  int _seenCancellations = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final scope = AppScope.of(context);
      _game = GameController(
        bot: widget.bot,
        playerSide: widget.playerSide,
        clockSetup: widget.clockSetup,
        engine: scope.engine,
        premovesEnabled: scope.settings.premovesEnabled,
      )..addListener(_onGameChanged);
      _game.start();
    }
  }

  void _onGameChanged() {
    if (_game.premoveCancellations != _seenCancellations) {
      _seenCancellations = _game.premoveCancellations;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Premove cancelled: no longer legal'),
        duration: Duration(milliseconds: 1200),
      ));
    }
    if (_game.isOver && !_resultShown) {
      _resultShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showResult();
      });
    }
  }

  String _resultTitle(GameResult r) {
    if (r.winner == null) return 'Draw';
    return r.winner == widget.playerSide ? 'You won!' : '${widget.bot.name} won';
  }

  Future<void> _showResult() {
    final r = _game.result!;
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_resultTitle(r)),
        content: Text('${r.score} · ${r.reason.label}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.insights),
            label: const Text('Game Review'),
            onPressed: () {
              Navigator.pop(context);
              _openReview();
            },
          ),
        ],
      ),
    );
  }

  void _openReview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewScreen(
          moves: _game.moves,
          result: _game.result,
          playerSide: widget.playerSide,
        ),
      ),
    );
  }

  void _rematch() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          bot: widget.bot,
          playerSide: widget.playerSide,
          clockSetup: widget.clockSetup,
        ),
      ),
    );
  }

  Future<void> _confirmResign() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resign this game?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Resign')),
        ],
      ),
    );
    if (yes ?? false) _game.resign();
  }

  @override
  void dispose() {
    _game.removeListener(_onGameChanged);
    _game.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return Scaffold(
      appBar: AppBar(
        title: Text('vs ${widget.bot.name}'),
        actions: [
          IconButton(
            tooltip: 'Flip board',
            icon: const Icon(Icons.swap_vert),
            onPressed: () =>
                setState(() => _orientation = _orientation.opposite),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([_game, settings]),
          builder: (context, _) {
            final game = _game;
            final topSide = _orientation.opposite;
            return LayoutBuilder(builder: (context, constraints) {
              final boardSize = constraints.maxWidth.clamp(0.0, constraints.maxHeight - 230);
              return Column(
                children: [
                  _playerBar(topSide),
                  Center(
                    child: SizedBox.square(
                      dimension: boardSize,
                      child: _board(game, settings),
                    ),
                  ),
                  _playerBar(_orientation),
                  _MoveStrip(moves: game.moves),
                  const Spacer(),
                  _actions(game),
                ],
              );
            });
          },
        ),
      ),
    );
  }

  Widget _board(GameController game, SettingsController settings) {
    final playerToMove = game.isPlayerTurn;
    final position = game.position;
    final last = game.lastMove;
    final checkSquare =
        position.isCheck ? position.board.kingOf(position.turn) : null;
    return ChessBoard(
      board: game.displayBoard,
      orientation: _orientation,
      theme: settings.theme,
      pieceSet: settings.pieceSet,
      showCoordinates: settings.showCoordinates,
      showLegalMoves: settings.showLegalMoves,
      highlightLastMove: settings.highlightLastMove,
      interactiveSide: game.isOver ? null : widget.playerSide,
      legalMoves: playerToMove ? _humanTargets(position) : const {},
      canPremove: !playerToMove && game.premovesEnabled,
      lastMove: last == null ? null : (last.move.from, _displayTo(last)),
      checkSquare: checkSquare,
      premoves: game.premoves,
      onMove: game.playerMove,
      onEmptyTap: game.clearPremoves,
    );
  }

  /// Highlight castling on the king's destination, not the rook.
  Square _displayTo(PlayedMove move) => Square.fromName(move.uci.substring(2, 4));

  /// Legal targets with castling shown as king two squares only.
  Map<Square, Set<Square>> _humanTargets(Position position) {
    final own = position.board.bySide(position.turn);
    return {
      for (final MapEntry(key: from, value: dests)
          in makeLegalMoves(position).entries)
        from: {for (final to in dests) if (!own.has(to)) to},
    };
  }

  Widget _playerBar(Side side) {
    final isBot = side == _game.botSide;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          if (isBot)
            BotAvatar(bot: widget.bot, radius: 18)
          else
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.primary,
              child: Icon(Icons.person, color: theme.colorScheme.onPrimary),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isBot ? '${widget.bot.name} (${widget.bot.ratingTag})' : 'You',
                    style: theme.textTheme.titleSmall),
                if (isBot && _game.botThinking)
                  Text('thinking…', style: theme.textTheme.bodySmall)
                else
                  Text(side == Side.white ? 'White' : 'Black',
                      style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          if (_game.clock.isTimed) _ClockFace(clock: _game.clock, side: side),
        ],
      ),
    );
  }

  Widget _actions(GameController game) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Row(
        children: [
          if (game.premoves.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.clear),
              label: Text('Premoves (${game.premoves.length})'),
              onPressed: game.clearPremoves,
            ),
          const Spacer(),
          if (game.isOver) ...[
            OutlinedButton(onPressed: _rematch, child: const Text('Rematch')),
            const SizedBox(width: 8),
            FilledButton.icon(
              icon: const Icon(Icons.insights),
              label: const Text('Review'),
              onPressed: _openReview,
            ),
          ] else
            OutlinedButton.icon(
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Resign'),
              onPressed: _confirmResign,
            ),
        ],
      ),
    );
  }
}

/// Clock face; rebuilds on clock ticks only.
class _ClockFace extends StatelessWidget {
  const _ClockFace({required this.clock, required this.side});

  final ChessClock clock;
  final Side side;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: clock,
      builder: (context, _) {
        final remaining = clock.remaining(side);
        final active = clock.running == side;
        final low = remaining < const Duration(seconds: 20);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? (low ? scheme.error : scheme.primary)
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            formatClock(remaining),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: active
                  ? (low ? scheme.onError : scheme.onPrimary)
                  : scheme.onSurface,
            ),
          ),
        );
      },
    );
  }
}

class _MoveStrip extends StatefulWidget {
  const _MoveStrip({required this.moves});

  final List<PlayedMove> moves;

  @override
  State<_MoveStrip> createState() => _MoveStripState();
}

class _MoveStripState extends State<_MoveStrip> {
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(_MoveStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.moves.length != oldWidget.moves.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moves = widget.moves;
    return SizedBox(
      height: 36,
      child: ListView.builder(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: moves.length,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Center(
            child: Text(
              i.isEven ? '${i ~/ 2 + 1}. ${moves[i].san}' : moves[i].san,
              style: TextStyle(
                fontWeight:
                    i == moves.length - 1 ? FontWeight.w800 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
