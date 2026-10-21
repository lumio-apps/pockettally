import 'package:flutter/material.dart';

/// A simple line chart with a soft fill under it, for a few dozen values.
/// Drawn by hand so the app needs no chart library.
class SimpleLineChart extends StatelessWidget {
  const SimpleLineChart({
    super.key,
    required this.values,
    required this.labels,
    required this.color,
    required this.axisLabel,
    this.height = 180,
  });

  final List<int> values;

  /// One short label per value, shown below the chart (only some are drawn
  /// when there are many).
  final List<String> labels;
  final Color color;

  /// Formats a value (minor units) for the axis, e.g. "12K".
  final String Function(int minor) axisLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: height,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => CustomPaint(
          size: Size.infinite,
          painter: _LinePainter(
            values: values,
            labels: labels,
            color: color,
            grid: theme.colorScheme.outlineVariant,
            textStyle: theme.textTheme.bodySmall!
                .copyWith(color: theme.colorScheme.onSurfaceVariant),
            axisLabel: axisLabel,
            progress: t,
          ),
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.values,
    required this.labels,
    required this.color,
    required this.grid,
    required this.textStyle,
    required this.axisLabel,
    required this.progress,
  });

  final List<int> values;
  final List<String> labels;
  final Color color;
  final Color grid;
  final TextStyle textStyle;
  final String Function(int) axisLabel;
  final double progress;

  void _text(Canvas canvas, String s, Offset at, {bool right = false}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: textStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    tp.paint(canvas, right ? Offset(at.dx - tp.width, at.dy) : at);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const axisW = 46.0;
    const bottomH = 22.0;
    const topPad = 8.0;
    final chart = Rect.fromLTRB(axisW, topPad, size.width - 8, size.height - bottomH);
    var lo = values.reduce((a, b) => a < b ? a : b);
    var hi = values.reduce((a, b) => a > b ? a : b);
    if (lo > 0) lo = 0;
    if (hi < 0) hi = 0;
    if (hi == lo) hi = lo + 1;
    double y(int v) => chart.bottom - (v - lo) / (hi - lo) * chart.height;
    double x(int i) => values.length == 1
        ? chart.center.dx
        : chart.left + i / (values.length - 1) * chart.width;

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final v in [lo, if (lo < 0 && hi > 0) 0, hi]) {
      final yy = y(v);
      canvas.drawLine(Offset(chart.left, yy), Offset(chart.right, yy), gridPaint);
      _text(canvas, axisLabel(v), Offset(axisW - 6, yy - 7), right: true);
    }

    // The line grows from left to right.
    final shown = (values.length - 1) * progress;
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      if (i > shown + 1) break;
      var px = x(i), py = y(values[i]);
      if (i > shown) {
        final frac = shown - (i - 1);
        final x0 = x(i - 1), y0 = y(values[i - 1]);
        px = x0 + (px - x0) * frac;
        py = y0 + (py - y0) * frac;
      }
      points.add(Offset(px, py));
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    final fill = Path()
      ..moveTo(points.first.dx, chart.bottom)
      ..lineTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
      fill.lineTo(p.dx, p.dy);
    }
    fill
      ..lineTo(points.last.dx, chart.bottom)
      ..close();
    canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.14));
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    if (progress >= 1) {
      canvas.drawCircle(
          Offset(x(values.length - 1), y(values.last)), 5, Paint()..color = color);
    }

    // Month labels: about six, evenly spread.
    final step = (values.length / 6).ceil().clamp(1, values.length);
    for (var i = 0; i < labels.length && i < values.length; i += step) {
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: textStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      tp.paint(canvas, Offset(x(i) - tp.width / 2, size.height - bottomH + 5));
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.values != values || old.progress != progress || old.color != color;
}
