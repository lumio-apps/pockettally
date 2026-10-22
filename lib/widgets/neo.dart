import 'package:flutter/material.dart';

import '../theme.dart';

/// The Lite look: flat cards with a thin border on a softly tinted page.
/// No blurred shadows, so every screen paints fast.

/// The colors of the look for a theme.
class NeoPalette {
  const NeoPalette({
    required this.base,
    required this.lo,
    required this.page,
    required this.well,
  });

  /// The card color (white, or a dark card in dark mode).
  final Color base;

  /// The thin card border.
  final Color lo;

  /// The page behind the cards, lightly tinted by the accent palette.
  final Color page;

  /// A slightly darker patch for progress tracks and fields.
  final Color well;

  factory NeoPalette.from(AppPalette palette, Brightness brightness) {
    if (brightness == Brightness.dark) {
      return NeoPalette(
        base: palette.surfaceDark,
        lo: Color.lerp(palette.surfaceDark, Colors.white, 0.12)!,
        page: palette.pageDark,
        well: Color.lerp(palette.surfaceDark, Colors.black, 0.30)!,
      );
    }
    return NeoPalette(
      base: Colors.white,
      lo: Color.lerp(palette.pageLight, const Color(0xFF9AA9C4), 0.30)!,
      page: palette.pageLight,
      well: Color.lerp(palette.pageLight, const Color(0xFF9AA9C4), 0.22)!,
    );
  }

  static NeoPalette of(BuildContext context) => NeoPalette.from(
        BrandColors.of(context).palette,
        Theme.of(context).brightness,
      );
}

/// A card: the card color with a thin border. With [onTap] it shows a
/// ripple. A drop-in for [Card]: it clips its child to the rounded shape.
class NeoCard extends StatelessWidget {
  const NeoCard({
    super.key,
    required this.child,
    this.radius = 20,
    this.padding,
    this.onTap,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final n = NeoPalette.of(context);
    final shape = BorderRadius.circular(radius);
    Widget content =
        padding == null ? child : Padding(padding: padding!, child: child);
    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: shape,
        splashColor: n.lo.withValues(alpha: 0.25),
        highlightColor: Colors.transparent,
        child: content,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: n.base,
        borderRadius: shape,
        border: Border.all(color: n.lo),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: shape,
        clipBehavior: clipBehavior,
        child: content,
      ),
    );
  }
}

/// A slightly darker patch (progress tracks, amount fields, icon wells).
class NeoInset extends StatelessWidget {
  const NeoInset({
    super.key,
    this.child,
    this.radius = 16,
    this.padding,
  });

  final Widget? child;
  final double radius;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final n = NeoPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: n.well,
        borderRadius: BorderRadius.circular(radius),
      ),
      child:
          padding == null ? child : Padding(padding: padding!, child: child),
    );
  }
}

/// Page change: a short fade.
class NeoPageTransitionsBuilder extends PageTransitionsBuilder {
  const NeoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      FadeTransition(opacity: animation, child: child);
}
