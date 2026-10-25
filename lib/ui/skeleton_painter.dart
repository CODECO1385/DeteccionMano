import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/settings.dart';
import '../analysis/finger_classifier.dart';
import 'theme.dart';

const _connections = <List<int>>[
  [0, 1], [1, 2], [2, 3], [3, 4],
  [0, 5], [5, 6], [6, 7], [7, 8],
  [5, 9], [9, 10], [10, 11], [11, 12],
  [9, 13], [13, 14], [14, 15], [15, 16],
  [13, 17], [17, 18], [18, 19], [19, 20],
  [0, 17],
];

Color _colorOf(int i) =>
    i == 0 ? Colors.white : fingerColors[Finger.values[(i - 1) ~/ 4]]!;

/// Dibuja el esqueleto sobre el video. El lienzo tiene exactamente la relación
/// de aspecto del video (el <video> usa object-fit: fill), así que x*ancho,
/// y*alto alinea con la imagen. Si el video se muestra reflejado, x -> 1-x.
class SkeletonPainter extends CustomPainter {
  SkeletonPainter(this.frame, this.settings) : super(repaint: frame);
  final ValueNotifier<FrameResult?> frame;
  final Settings settings;

  @override
  void paint(Canvas canvas, Size size) {
    final f = frame.value;
    if (f == null) return;
    final line = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final dot = Paint()..style = PaintingStyle.fill;
    for (final h in f.hands) {
      if (h.lm.length != 21) continue;
      Offset o(int i) => Offset(
          (settings.mirror ? 1 - h.lm[i].x : h.lm[i].x) * size.width, h.lm[i].y * size.height);
      for (final c in _connections) {
        line.color = _colorOf(c[1]).withOpacity(0.9);
        canvas.drawLine(o(c[0]), o(c[1]), line);
      }
      for (var i = 0; i < 21; i++) {
        final tip = i != 0 && i % 4 == 0;
        dot.color = Colors.white;
        canvas.drawCircle(o(i), tip ? 7 : 5, dot);
        dot.color = _colorOf(i);
        canvas.drawCircle(o(i), tip ? 5 : 3.5, dot);
      }
      final tp = TextPainter(
        text: TextSpan(
            text: '${settings.handLabel(h.rawLabel)} ${(h.score * 100).round()}%',
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600,
                backgroundColor: Color(0x99000000))),
        textDirection: TextDirection.ltr,
      )..layout();
      final w = o(0);
      tp.paint(canvas, Offset((w.dx - tp.width / 2).clamp(0.0, size.width - tp.width).toDouble(), (w.dy + 10).clamp(0.0, size.height - tp.height).toDouble()));
    }
  }

  @override
  bool shouldRepaint(SkeletonPainter old) => old.settings != settings || old.frame != frame;
}
