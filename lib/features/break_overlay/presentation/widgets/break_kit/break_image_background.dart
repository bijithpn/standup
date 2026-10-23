import 'package:flutter/material.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';

/// Photo background that never shows black: a gradient sits underneath, the
/// image fades in over [BreakMotion.slow] once decoded, and a failed load just
/// leaves the gradient visible.
class BreakImageBackground extends StatelessWidget {
  final ImageProvider? image;
  final List<Color> fallback;
  final BoxFit fit;

  /// Rendering transform (e.g. a Ken Burns scale) applied to the image only.
  final Widget Function(Widget image)? imageBuilder;

  const BreakImageBackground({
    super.key,
    this.image,
    required this.fallback,
    this.fit = BoxFit.cover,
    this.imageBuilder,
  });

  /// Warm the image cache so the first frame of a break is not blank.
  static Future<void> precache(BuildContext context, ImageProvider image) =>
      precacheImage(image, context).catchError((_) {});

  @override
  Widget build(BuildContext context) {
    final img = image;
    Widget? photo;
    if (img != null) {
      photo = Image(
        image: img,
        fit: fit,
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
        frameBuilder: (context, child, frame, sync) {
          if (sync) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: BreakMotion.slow,
            curve: Curves.easeOut,
            child: child,
          );
        },
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
      if (imageBuilder != null) photo = imageBuilder!(photo);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: fallback,
            ),
          ),
        ),
        ?photo,
      ],
    );
  }
}
