import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_skip_button.dart';

/// Shared frame for every break template.
///
/// Paints the canvas and an optional [background] full-bleed, lays [child]
/// out in a fixed [designSize] box scaled to fit (so thumbnails and tiny
/// windows never overflow), binds Esc to skip, and places the skip button.
class BreakScaffold extends StatelessWidget {
  static const Size defaultDesignSize = Size(1280, 800);

  final Widget child;

  /// Full-bleed layer(s) under the content. Wrapped in a [RepaintBoundary].
  final Widget? background;

  /// Canvas color; defaults to the palette canvas. Pass
  /// [Colors.transparent] for templates that float over the desktop.
  final Color? canvas;

  /// Tint drawn over a transparent canvas or background.
  final Color? scrim;

  /// Pins a palette for this template ("fixed" templates).
  final BreakPalette? palette;

  final VoidCallback? onSkip;
  final bool strictMode;

  /// Whether the scaffold draws the skip button itself. Esc is bound either
  /// way.
  final bool showSkip;

  /// Reserved space at the top for chrome drawn over the template.
  final double safeTopInset;

  /// Lay [child] out in [designSize] and scale to fit. Templates that work in
  /// real screen coordinates (draggable widgets) pass false.
  final bool scaled;
  final Size designSize;
  final Color? accent;

  const BreakScaffold({
    super.key,
    required this.child,
    this.background,
    this.canvas,
    this.scrim,
    this.palette,
    this.onSkip,
    this.strictMode = false,
    this.showSkip = true,
    this.safeTopInset = 0,
    this.scaled = true,
    this.designSize = defaultDesignSize,
    this.accent,
  });

  bool get _canSkip => !strictMode && onSkip != null;

  @override
  Widget build(BuildContext context) {
    final pal = palette ?? BreakPalette.of(context);
    final preview = BreakPreviewScope.isPreview(context);
    final transparent = canvas == Colors.transparent;

    Widget content = child;
    if (scaled) {
      content = FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: designSize.width,
          height: designSize.height,
          child: child,
        ),
      );
    }

    Widget stack = Stack(
      fit: StackFit.expand,
      children: [
        if (transparent)
          (preview ? const _FauxDesktop() : const SizedBox.shrink())
        else
          ColoredBox(color: canvas ?? pal.canvas),
        if (background != null)
          Positioned.fill(child: RepaintBoundary(child: background)),
        if (scrim != null) ColoredBox(color: scrim!),
        Padding(
          padding: EdgeInsets.only(top: safeTopInset),
          child: content,
        ),
        if (_canSkip && showSkip)
          Positioned(
            bottom: BreakOverlayTheme.skipBottom,
            right: BreakOverlayTheme.skipRight,
            child: BreakSkipButton(onPressed: onSkip!, accent: accent),
          ),
      ],
    );

    if (_canSkip) {
      stack = CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () => onSkip!(),
        },
        // includeSemantics: false keeps this focus node from merging the whole
        // page into a single accessibility node.
        child: Focus(
          autofocus: !preview,
          includeSemantics: false,
          child: stack,
        ),
      );
    }

    return BreakPaletteScope(
      palette: pal,
      child: Material(
        type: MaterialType.transparency,
        child: DefaultTextStyle(
          style: BreakOverlayTheme.body.copyWith(color: pal.textPrimary),
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            child: stack,
          ),
        ),
      ),
    );
  }
}

/// Stand-in for the user's desktop behind translucent templates, used only in
/// gallery thumbnails.
class _FauxDesktop extends StatelessWidget {
  const _FauxDesktop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B4F6B), Color(0xFF7D8FA6)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, c) => Stack(
          children: [
            Positioned(
              left: c.maxWidth * 0.08,
              top: c.maxHeight * 0.12,
              width: c.maxWidth * 0.55,
              height: c.maxHeight * 0.6,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            Positioned(
              left: c.maxWidth * 0.38,
              top: c.maxHeight * 0.28,
              width: c.maxWidth * 0.5,
              height: c.maxHeight * 0.55,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFE8ECF2).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
