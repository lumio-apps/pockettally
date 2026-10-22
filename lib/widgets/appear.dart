import 'package:flutter/material.dart';

/// A money amount, scaled down to fit one line.
class CountUp extends StatelessWidget {
  const CountUp(
      {super.key, required this.value, required this.format, this.style});

  final int value;
  final String Function(int) format;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    // The amount just shows, no counting animation.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Text(format(value), style: style),
    );
  }
}
