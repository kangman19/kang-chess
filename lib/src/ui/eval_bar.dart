import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../domain/score.dart';

/// Vertical evaluation bar. [evalWhite] is from White's point of view.
class EvalBar extends StatelessWidget {
  const EvalBar({
    super.key,
    required this.evalWhite,
    required this.orientation,
    this.width = 22,
  });

  final Score? evalWhite;
  final Side orientation;
  final double width;

  @override
  Widget build(BuildContext context) {
    final eval = evalWhite;
    final whiteShare = eval == null ? 0.5 : eval.winProbability;
    final whiteAtBottom = orientation == Side.white;
    return SizedBox(
      width: width,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: whiteShare),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          builder: (context, share, _) => CustomPaint(
            painter: _EvalPainter(share, whiteAtBottom),
            child: Align(
              alignment: (share >= 0.5) == whiteAtBottom
                  ? Alignment.bottomCenter
                  : Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  eval == null ? '' : _label(eval),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: share >= 0.5 ? Colors.black87 : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _label(Score s) {
    final m = s.mate;
    if (m != null) return m == 0 ? '#' : 'M${m.abs()}';
    return (s.cp!.abs() / 100).toStringAsFixed(1);
  }
}

class _EvalPainter extends CustomPainter {
  _EvalPainter(this.whiteShare, this.whiteAtBottom);

  final double whiteShare;
  final bool whiteAtBottom;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF403D39));
    final whiteHeight = size.height * whiteShare;
    final top = whiteAtBottom ? size.height - whiteHeight : 0.0;
    canvas.drawRect(Rect.fromLTWH(0, top, size.width, whiteHeight),
        Paint()..color = const Color(0xFFF1F1F1));
  }

  @override
  bool shouldRepaint(_EvalPainter old) =>
      old.whiteShare != whiteShare || old.whiteAtBottom != whiteAtBottom;
}
