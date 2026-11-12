import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../app.dart';
import '../../domain/move_classification.dart';
import '../../game/game_controller.dart';
import '../../review/review_controller.dart';
import '../board/chess_board.dart';
import '../eval_bar.dart';
import '../move_class_style.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.moves,
    required this.result,
    required this.playerSide,
  });

  final List<PlayedMove> moves;
  final GameResult? result;
  final Side playerSide;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  ReviewController? _review;
  late Side _orientation = widget.playerSide;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_review == null) {
      final scope = AppScope.of(context);
      _review = ReviewController(
        moves: widget.moves,
        result: widget.result,
        playerSide: widget.playerSide,
        engine: scope.engine,
        depth: scope.settings.reviewDepth,
      )..start();
    }
  }

  @override
  void dispose() {
    _review?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final review = _review!;
    final settings = AppScope.of(context).settings;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Review'),
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
          listenable: Listenable.merge([review, settings]),
          builder: (context, _) {
            final ply = review.selectedPly;
            final position = review.positionAt(ply);
            final current = review.reviewAt(ply);
            final nextBest = review.evalAt(ply)?.bestMove;
            final arrows = <BoardArrow>[
              if (current != null &&
                  current.bestMoveUci != null &&
                  current.bestMoveUci != current.played.uci)
                _arrow(current.bestMoveUci!, const Color(0xCC7FA650)),
              if (nextBest != null && ply < review.plyCount)
                _arrow(nextBest, const Color(0x995C8BB0)),
            ];
            final playedTo = current == null
                ? null
                : Square.fromName(current.played.uci.substring(2, 4));
            return LayoutBuilder(builder: (context, constraints) {
              // Row padding (16) + eval bar (22) + gap (6).
              final boardSize = (constraints.maxWidth - 44)
                  .clamp(0.0, constraints.maxHeight * 0.55);
              return Column(
                children: [
                  if (!review.isFinished)
                    LinearProgressIndicator(value: review.progress),
                  if (review.error != null)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text('Engine error: ${review.error}',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: boardSize,
                          child: EvalBar(
                            evalWhite: review.selectedEvalWhite,
                            orientation: _orientation,
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox.square(
                          dimension: boardSize,
                          child: ChessBoard(
                            board: position.board,
                            orientation: _orientation,
                            theme: settings.theme,
                            pieceSet: settings.pieceSet,
                            showCoordinates: settings.showCoordinates,
                            lastMove: current == null
                                ? null
                                : (current.played.move.from, playedTo!),
                            checkSquare: position.isCheck
                                ? position.board.kingOf(position.turn)
                                : null,
                            arrows: arrows,
                            badge: current == null
                                ? null
                                : (playedTo!, current.classification),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _Explanation(review: review),
                  _NavBar(review: review),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        _Summary(review: review, result: widget.result),
                        const SizedBox(height: 8),
                        _MoveTable(review: review),
                      ],
                    ),
                  ),
                ],
              );
            });
          },
        ),
      ),
    );
  }

  BoardArrow _arrow(String uci, Color color) => BoardArrow(
        Square.fromName(uci.substring(0, 2)),
        Square.fromName(uci.substring(2, 4)),
        color,
      );
}

class _Explanation extends StatelessWidget {
  const _Explanation({required this.review});

  final ReviewController review;

  @override
  Widget build(BuildContext context) {
    final r = review.reviewAt(review.selectedPly);
    final textTheme = Theme.of(context).textTheme;
    if (review.selectedPly == 0) {
      return Text('Starting position', style: textTheme.titleSmall);
    }
    if (r == null) {
      return Text('Analyzing…', style: textTheme.titleSmall);
    }
    final cls = r.classification;
    final article = cls == MoveClass.inaccuracy ||
            cls == MoveClass.excellent ||
            cls == MoveClass.miss
        ? 'an'
        : 'a';
    final verdict = switch (cls) {
      MoveClass.best => '${r.played.san} is the best move',
      MoveClass.book => '${r.played.san} is a book move',
      MoveClass.miss => '${r.played.san} is a miss',
      _ => '${r.played.san} is $article ${cls.label.toLowerCase()} move',
    };
    final showBest = r.bestMoveSan != null &&
        r.bestMoveUci != r.played.uci &&
        cls != MoveClass.book;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _Badge(cls),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              showBest ? '$verdict. Best was ${r.bestMoveSan}.' : '$verdict.',
              style: textTheme.titleSmall,
            ),
          ),
          Text(r.evalWhite.display, style: textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.review});

  final ReviewController review;

  @override
  Widget build(BuildContext context) {
    final ply = review.selectedPly;
    final prevKey = review.previousKeyMove;
    final nextKey = review.nextKeyMove;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
            icon: const Icon(Icons.first_page),
            tooltip: 'Previous key move',
            onPressed: prevKey != null ? () => review.select(prevKey) : null),
        IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: ply > 0 ? () => review.select(ply - 1) : null),
        Text('$ply / ${review.plyCount}'),
        IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: ply < review.plyCount
                ? () => review.select(ply + 1)
                : null),
        IconButton(
            icon: const Icon(Icons.last_page),
            tooltip: 'Next key move',
            onPressed: nextKey != null ? () => review.select(nextKey) : null),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.review, required this.result});

  final ReviewController review;
  final GameResult? result;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    String acc(Side side) {
      final a = review.accuracy(side);
      return a == null ? '–' : a.toStringAsFixed(1);
    }

    final white = review.counts(Side.white);
    final black = review.counts(Side.black);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (result != null)
              Text('${result!.score} · ${result!.reason.label}',
                  style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(child: Text('Accuracy')),
                _AccuracyChip(acc(Side.white), light: true),
                const SizedBox(width: 8),
                _AccuracyChip(acc(Side.black), light: false),
              ],
            ),
            const Divider(),
            for (final cls in MoveClass.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                        width: 44,
                        child: Text('${white[cls]}', textAlign: TextAlign.center)),
                    _Badge(cls, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(cls.label)),
                    SizedBox(
                        width: 44,
                        child: Text('${black[cls]}', textAlign: TextAlign.center)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AccuracyChip extends StatelessWidget {
  const _AccuracyChip(this.text, {required this.light});

  final String text;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: light ? const Color(0xFFF1F1F1) : const Color(0xFF403D39),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: light ? Colors.black87 : Colors.white,
        ),
      ),
    );
  }
}

class _MoveTable extends StatelessWidget {
  const _MoveTable({required this.review});

  final ReviewController review;

  @override
  Widget build(BuildContext context) {
    final rows = (review.plyCount + 1) ~/ 2;
    return Column(
      children: [
        for (var row = 0; row < rows; row++)
          Row(
            children: [
              SizedBox(width: 36, child: Text('${row + 1}.')),
              Expanded(child: _cell(context, row * 2 + 1)),
              Expanded(child: _cell(context, row * 2 + 2)),
            ],
          ),
      ],
    );
  }

  Widget _cell(BuildContext context, int ply) {
    if (ply > review.plyCount) return const SizedBox.shrink();
    final r = review.reviewAt(ply);
    final selected = review.selectedPly == ply;
    return InkWell(
      onTap: () => review.select(ply),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        color: selected
            ? Theme.of(context).colorScheme.primaryContainer
            : null,
        child: Row(
          children: [
            if (r != null) ...[
              _Badge(r.classification, size: 18),
              const SizedBox(width: 6),
            ],
            Flexible(child: Text(review.moves[ply - 1].san)),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.cls, {this.size = 26});

  final MoveClass cls;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: cls.color, shape: BoxShape.circle),
      child: Text(
        cls.badge,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: size * 0.5,
        ),
      ),
    );
  }
}
