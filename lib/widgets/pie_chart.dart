import 'dart:math' as math;

import 'package:flutter/material.dart';

class PieSlice {
  const PieSlice(this.value, this.color);

  final double value;
  final Color color;
}

/// A simple donut chart. Drawn by hand so the app needs no chart library.
class PieChart extends StatelessWidget {
  const PieChart({
    super.key,
    required this.slices,
    this.size = 200,
    this.center,
  });

  final List<PieSlice> slices;
  final double size;

  /// Widget shown in the hole of the donut (e.g. the total).
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _PiePainter(
              slices,
              Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
          if (center != null)
            SizedBox(width: size * 0.55, child: Center(child: center)),
        ],
      ),
    );
  }
}

class _PiePainter extends CustomPainter {
  _PiePainter(this.slices, this.emptyColor);

  final List<PieSlice> slices;
  final Color emptyColor;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.16;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    final total = slices.fold<double>(0, (s, e) => s + e.value);
    if (total <= 0) {
      canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = emptyColor);
      return;
    }

    final visible = slices.where((s) => s.value > 0).toList();
    // Small gap between slices, none when there is only one.
    final gap = visible.length > 1 ? 0.03 : 0.0;
    var start = -math.pi / 2;
    for (final s in visible) {
      final sweep = s.value / total * math.pi * 2;
      final drawn = math.max(sweep - gap, 0.005);
      canvas.drawArc(rect, start + gap / 2, drawn, false, paint..color = s.color);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PiePainter old) =>
      old.slices != slices || old.emptyColor != emptyColor;
}
