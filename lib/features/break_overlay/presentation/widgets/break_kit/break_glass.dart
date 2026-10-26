import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';

/// Frosted surface: backdrop blur (sigma 20), translucent surface fill and a
/// 1px inner border. The blur is clipped to the widget's own bounds, which
/// keeps its cost proportional to the card, not the screen.
class BreakGlass extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  /// Surface fill alpha (spec: 0.6).
  final double fillAlpha;

  /// Border alpha: white in dark, ink in light (spec: 0.10).
  final double borderAlpha;
  final bool shadow;
  final Color? borderColor;

  /// Skip the backdrop blur (an opaque-ish pill that sits on a plain scrim).
  final bool blur;

  const BreakGlass({
    super.key,
    required this.child,
    this.radius = BreakOverlayTheme.radiusLg,
    this.padding = EdgeInsets.zero,
    this.fillAlpha = 0.6,
    this.borderAlpha = 0.10,
    this.shadow = true,
    this.borderColor,
    this.blur = true,
  });

  Widget _maybeBlur(Widget w) => blur
      ? BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: BreakOverlayTheme.glassBlur,
            sigmaY: BreakOverlayTheme.glassBlur,
          ),
          child: w,
        )
      : w;

  @override
  Widget build(BuildContext context) {
    final palette = BreakPalette.of(context);
    final r = BorderRadius.circular(radius);
    return CustomPaint(
      painter: shadow ? _OuterShadowPainter(radius) : null,
      child: ClipRRect(
        borderRadius: r,
        child: _maybeBlur(
          DecoratedBox(
            decoration: BoxDecoration(
              color: palette.surface.withValues(alpha: fillAlpha),
              borderRadius: r,
              border: Border.all(
                color:
                    borderColor ??
                    (palette.isDark
                        ? Colors.white.withValues(alpha: borderAlpha)
                        : const Color(
                            0xFF1C1F24,
                          ).withValues(alpha: borderAlpha)),
              ),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// Paints the surface drop shadow *outside* the rounded rect only, so it does
/// not show through the translucent glass fill.
class _OuterShadowPainter extends CustomPainter {
  final double radius;

  _OuterShadowPainter(this.radius);

  final Paint _paint = Paint()
    ..color = const Color(0x47000000)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect((Offset.zero & size).inflate(120)),
      Path()..addRRect(rrect),
    );
    canvas
      ..save()
      ..clipPath(outside)
      ..drawRRect(rrect.shift(const Offset(0, 12)), _paint)
      ..restore();
  }

  @override
  bool shouldRepaint(covariant _OuterShadowPainter old) => old.radius != radius;
}
