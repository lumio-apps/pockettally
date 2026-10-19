import 'package:flutter/material.dart';

import '../theme.dart';

/// The neumorphic look: one soft base color, with shapes that look pushed
/// out of it (raised, a light and a dark shadow) or pressed into it (inset).

/// The three colors of the look for a theme: the surface itself, the light
/// edge (top left) and the dark edge (bottom right).
class NeoPalette {
  const NeoPalette({required this.base, required this.hi, required this.lo});

  final Color base;
  final Color hi;
  final Color lo;

  /// The colors for [palette] in [brightness]: the accent color tints the
  /// surface a little, so every accent color gets its own soft look.
  factory NeoPalette.from(AppPalette palette, Brightness brightness) {
    if (brightness == Brightness.dark) {
      final base = Color.lerp(palette.surfaceDark, Colors.white, 0.05)!;
      return NeoPalette(
        base: base,
        hi: Color.lerp(base, Colors.white, 0.08)!,
        lo: Color.lerp(base, Colors.black, 0.50)!,
      );
    }
    final base = Color.lerp(palette.pageLight, const Color(0xFFC9D2E0), 0.55)!;
    return NeoPalette(
      base: base,
      hi: Colors.white,
      lo: Color.lerp(base, const Color(0xFF7F8EA8), 0.55)!,
    );
  }

  static NeoPalette of(BuildContext context) => NeoPalette.from(
        BrandColors.of(context).palette,
        Theme.of(context).brightness,
      );

  /// A shape pushed out of the surface. [depth] 1 is the normal size.
  List<BoxShadow> raised([double depth = 1]) => [
        BoxShadow(
          color: lo.withValues(alpha: 0.85),
          blurRadius: 18 * depth,
          offset: Offset(8 * depth, 8 * depth),
        ),
        BoxShadow(
          color: hi.withValues(alpha: 0.9),
          blurRadius: 18 * depth,
          offset: Offset(-8 * depth, -8 * depth),
        ),
      ];
}

/// Fill and shadows of a raised shape, for a [DecoratedBox] or a [Container].
BoxDecoration neoDecoration(
  BuildContext context, {
  double radius = 24,
  double depth = 1,
  BoxShape shape = BoxShape.rectangle,
}) {
  final n = NeoPalette.of(context);
  return BoxDecoration(
    color: n.base,
    shape: shape,
    borderRadius:
        shape == BoxShape.circle ? null : BorderRadius.circular(radius),
    boxShadow: n.raised(depth),
  );
}

/// A raised card. With [onTap] it sinks in while it is pressed.
/// A drop-in for [Card]: it clips its child to the rounded shape.
class NeoCard extends StatefulWidget {
  const NeoCard({
    super.key,
    required this.child,
    this.radius = 22,
    this.padding,
    this.onTap,
    this.depth = 0.8,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double depth;
  final Clip clipBehavior;

  @override
  State<NeoCard> createState() => _NeoCardState();
}

class _NeoCardState extends State<NeoCard> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final n = NeoPalette.of(context);
    final radius = BorderRadius.circular(widget.radius);
    Widget content = widget.padding == null
        ? widget.child
        : Padding(padding: widget.padding!, child: widget.child);
    if (widget.onTap != null) {
      content = InkWell(
        onTap: widget.onTap,
        borderRadius: radius,
        splashColor: n.lo.withValues(alpha: 0.12),
        highlightColor: Colors.transparent,
        onHighlightChanged: (v) {
          if (mounted) setState(() => _down = v);
        },
        child: content,
      );
    }
    return AnimatedScale(
      scale: _down ? 0.985 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: n.base,
          borderRadius: radius,
          boxShadow: n.raised(_down ? widget.depth * 0.3 : widget.depth),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: radius,
          clipBehavior: widget.clipBehavior,
          child: content,
        ),
      ),
    );
  }
}

/// A shape pressed into the surface (progress tracks, amount fields,
/// the selected tab).
class NeoInset extends StatelessWidget {
  const NeoInset({
    super.key,
    this.child,
    this.radius = 20,
    this.padding,
    this.depth = 0.8,
  });

  final Widget? child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final double depth;

  @override
  Widget build(BuildContext context) {
    final n = NeoPalette.of(context);
    return CustomPaint(
      painter: _InsetPainter(
        base: n.base,
        hi: n.hi,
        lo: n.lo,
        radius: radius,
        depth: depth,
      ),
      child: padding == null
          ? child
          : Padding(padding: padding!, child: child),
    );
  }
}

class _InsetPainter extends CustomPainter {
  const _InsetPainter({
    required this.base,
    required this.hi,
    required this.lo,
    required this.radius,
    required this.depth,
  });

  final Color base;
  final Color hi;
  final Color lo;
  final double radius;
  final double depth;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRRect(rrect, Paint()..color = base);
    final sigma = 5.0 * depth;
    final outer = Path()..addRect(rrect.outerRect.inflate(80));
    void shade(Offset shift, Color color) {
      final hole = Path()..addRRect(rrect.shift(shift));
      canvas.drawPath(
        Path.combine(PathOperation.difference, outer, hole),
        Paint()
          ..color = color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma),
      );
    }

    // Dark edge inside the top left, light edge inside the bottom right.
    shade(Offset(5 * depth, 5 * depth), lo.withValues(alpha: 0.85));
    shade(Offset(-5 * depth, -5 * depth), hi.withValues(alpha: 0.9));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_InsetPainter old) =>
      old.base != base ||
      old.hi != hi ||
      old.lo != lo ||
      old.radius != radius ||
      old.depth != depth;
}

/// Page change: a short fade with a small slide up.
class NeoPageTransitionsBuilder extends PageTransitionsBuilder {
  const NeoPageTransitionsBuilder();

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
        child: child,
      ),
    );
  }
}
