import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme.dart';

/// The glass look: a soft gradient with a few glowing colors behind
/// frosted, translucent cards.

/// Fill, border and shadow of a glass card for the current theme.
BoxDecoration glassDecoration(
  BuildContext context, {
  double radius = 24,
  Color? tint,
}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final borderRadius = BorderRadius.circular(radius);
  if (tint != null) {
    return BoxDecoration(
      borderRadius: borderRadius,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          tint.withValues(alpha: dark ? 0.28 : 0.20),
          tint.withValues(alpha: dark ? 0.12 : 0.08),
        ],
      ),
      border: Border.all(color: tint.withValues(alpha: dark ? 0.40 : 0.30)),
    );
  }
  return BoxDecoration(
    borderRadius: borderRadius,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: dark
          ? [
              Colors.white.withValues(alpha: 0.16),
              Colors.white.withValues(alpha: 0.06),
            ]
          : [
              Colors.white.withValues(alpha: 0.82),
              Colors.white.withValues(alpha: 0.54),
            ],
    ),
    border: Border.all(
      color: Colors.white.withValues(alpha: dark ? 0.24 : 0.90),
    ),
    boxShadow: [
      BoxShadow(
        color: dark
            ? const Color(0x59050A1E)
            : const Color(0x141B2B55),
        blurRadius: 24,
        offset: const Offset(0, 10),
      ),
    ],
  );
}

/// A translucent card with a light border. Cheap to draw: it has no blur,
/// because the page behind it is a smooth gradient.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.radius = 24,
    this.padding,
    this.onTap,
    this.tint,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  /// A color for the glass (income green, expense red…); null = white glass.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    Widget content = padding == null
        ? child
        : Padding(padding: padding!, child: child);
    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: content,
      );
    }
    return DecoratedBox(
      decoration: glassDecoration(context, radius: radius, tint: tint),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: content,
      ),
    );
  }
}

/// A frosted bar that blurs whatever is behind it.
class FrostedBar extends StatelessWidget {
  const FrostedBar({super.key, required this.child, this.radius = 34});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: glassDecoration(context, radius: radius),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: child,
        ),
      ),
    );
  }
}

/// The page background: a gradient in the colors of the chosen palette,
/// with glowing spots. Every page gets it from the page transition, so
/// the pages themselves have a transparent background.
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final p = BrandColors.of(context).palette;
    final base = dark ? p.pageDark : p.pageLight;
    final mid = Color.lerp(base, p.brand, dark ? 0.30 : 0.10)!;
    final end = Color.lerp(base, p.light, dark ? 0.22 : 0.34)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(-0.4, -1),
          end: const Alignment(0.4, 1),
          colors: [base, mid, end],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              painter: _GlowPainter(
                brand: p.brand,
                light: p.light,
                dark: dark,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter({
    required this.brand,
    required this.light,
    required this.dark,
  });

  final Color brand;
  final Color light;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    void glow(double x, double y, double radius, Color color, double alpha) {
      final center = Offset(size.width * x, size.height * y);
      final r = size.shortestSide * radius;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: r));
      canvas.drawCircle(center, r, paint);
    }

    glow(0.05, 0.16, 0.85, brand, dark ? 0.70 : 0.22);
    glow(0.92, 0.02, 0.70, light, dark ? 0.45 : 0.45);
    glow(0.90, 0.55, 0.60, kAccent, dark ? 0.26 : 0.24);
    glow(0.05, 0.92, 0.65, kMint, dark ? 0.22 : 0.30);
  }

  @override
  bool shouldRepaint(_GlowPainter old) =>
      old.brand != brand || old.light != light || old.dark != dark;
}

/// Page change: a short fade with a small slide up, on top of the glass
/// background, so that each page has its own background.
class GlassPageTransitionsBuilder extends PageTransitionsBuilder {
  const GlassPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final eased = animation.drive(CurveTween(curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: eased,
      child: SlideTransition(
        position: eased.drive(
          Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero),
        ),
        child: GlassBackground(child: child),
      ),
    );
  }
}
