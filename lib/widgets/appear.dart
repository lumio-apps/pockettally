import 'package:flutter/material.dart';

import 'neo.dart';

/// Fades and slides a section in, a little later for each one, the first
/// time it is built. Used for the sections of Home and Reports.
class Appear extends StatelessWidget {
  const Appear({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Only the first screenful animates; further down appears at once.
    if (index > 8 || NeoEffects.reduceOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + index * 45),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child),
      ),
    );
  }
}

/// A money amount that counts up (or down) to [value] when it changes.
class CountUp extends StatelessWidget {
  const CountUp(
      {super.key, required this.value, required this.format, this.style});

  final int value;
  final String Function(int) format;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value.toDouble()),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Text(format(v.round()), style: style),
      ),
    );
  }
}
