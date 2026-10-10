import 'dart:math' as math;

import 'package:flutter/material.dart';

class BarGroup {
  const BarGroup(this.label, this.income, this.expense);

  final String label;
  final int income;
  final int expense;
}

/// Income and expense bars side by side for each group (e.g. each month).
/// Drawn by hand so the app needs no chart library.
class IncomeExpenseBarChart extends StatelessWidget {
  const IncomeExpenseBarChart({
    super.key,
    required this.groups,
    required this.incomeColor,
    required this.expenseColor,
    required this.axisLabel,
    this.height = 200,
  });

  final List<BarGroup> groups;
  final Color incomeColor;
  final Color expenseColor;

  /// Formats a value (in minor units) for the axis, e.g. "12K".
  final String Function(int minor) axisLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxValue = groups.fold<int>(
        0, (m, g) => math.max(m, math.max(g.income, g.expense)));
    final top = maxValue <= 0 ? 1 : maxValue;
    const axisWidth = 44.0;

    return Column(
      children: [
        SizedBox(
          height: height,
          child: CustomPaint(
            size: Size.infinite,
            painter: _BarPainter(
              groups: groups,
              top: top,
              incomeColor: incomeColor,
              expenseColor: expenseColor,
              gridColor: theme.colorScheme.outlineVariant,
              labelStyle: theme.textTheme.bodySmall!
                  .copyWith(color: theme.colorScheme.onSurfaceVariant),
              axisLabel: axisLabel,
              axisWidth: axisWidth,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const SizedBox(width: axisWidth),
            for (final g in groups)
              Expanded(
                child: Text(
                  g.label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Legend(color: incomeColor, label: 'Income'),
            const SizedBox(width: 20),
            _Legend(color: expenseColor, label: 'Expenses'),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.groups,
    required this.top,
    required this.incomeColor,
    required this.expenseColor,
    required this.gridColor,
    required this.labelStyle,
    required this.axisLabel,
    required this.axisWidth,
  });

  final List<BarGroup> groups;
  final int top;
  final Color incomeColor;
  final Color expenseColor;
  final Color gridColor;
  final TextStyle labelStyle;
  final String Function(int minor) axisLabel;
  final double axisWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final chartLeft = axisWidth;
    final chartWidth = size.width - axisWidth;
    final chartHeight = size.height - 8; // room for the top label
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    // Grid lines and axis labels at 0, 50 % and 100 %.
    for (final f in const [0.0, 0.5, 1.0]) {
      final y = size.height - chartHeight * f;
      canvas.drawLine(Offset(chartLeft, y), Offset(size.width, y), grid);
      final tp = TextPainter(
        text: TextSpan(text: axisLabel((top * f).round()), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: axisWidth - 4);
      tp.paint(canvas, Offset(axisWidth - 6 - tp.width, y - tp.height / 2));
    }

    if (groups.isEmpty) return;
    final groupWidth = chartWidth / groups.length;
    final barWidth = math.min(groupWidth * 0.32, 18.0);
    final paint = Paint();
    final radius = Radius.circular(math.min(barWidth / 2, 4));

    for (var i = 0; i < groups.length; i++) {
      final g = groups[i];
      final centerX = chartLeft + groupWidth * (i + 0.5);
      void bar(int value, double left, Color color) {
        if (value <= 0) return;
        final h = math.max(chartHeight * value / top, 2.0);
        final rect = RRect.fromRectAndCorners(
          Rect.fromLTWH(left, size.height - h, barWidth, h),
          topLeft: radius,
          topRight: radius,
        );
        canvas.drawRRect(rect, paint..color = color);
      }

      bar(g.income, centerX - barWidth - 1, incomeColor);
      bar(g.expense, centerX + 1, expenseColor);
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) => true;
}
