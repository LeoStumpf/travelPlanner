import 'package:flutter/material.dart';

/// A dashed rounded-rectangle outline: marks placeholders ("+ Transport",
/// free days) and tentative items (options, ideas), so they differ from
/// planned ones by shape, not only by colour or opacity.
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  const DashedBorderPainter(this.color, {this.radius = 8, this.strokeWidth = 1.2, this.dash = 5, this.gap = 4});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final inset = strokeWidth / 2;
    final rect = Rect.fromLTWH(inset, inset, size.width - strokeWidth, size.height - strokeWidth);
    final path = Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth ||
      old.dash != dash ||
      old.gap != gap;
}

/// A horizontal dashed bar (a tentative place's line in the timeline).
class DashedLinePainter extends CustomPainter {
  final Color color;
  final double dash;
  final double gap;

  /// Dashes run down instead of across.
  final bool vertical;
  const DashedLinePainter(this.color, {this.dash = 10, this.gap = 5, this.vertical = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final length = vertical ? size.height : size.width;
    final thickness = vertical ? size.width : size.height;
    final r = Radius.circular(thickness / 2);
    for (var x = 0.0; x < length; x += dash + gap) {
      final w = (length - x).clamp(0.0, dash);
      final rect = vertical ? Rect.fromLTWH(0, x, thickness, w) : Rect.fromLTWH(x, 0, w, thickness);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, r), paint);
    }
  }

  @override
  bool shouldRepaint(DashedLinePainter old) =>
      old.color != color || old.dash != dash || old.gap != gap || old.vertical != vertical;
}
