import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_skip_button.dart';

/// Common frame for every template: background, palette scope, fixed-design-size scaling, Esc and Skip handling (hidden in strict mode).
class BreakScaffold extends StatelessWidget {
  static const Size defaultDesignSize = Size(1280, 800);

  final Widget child;

  final Widget? background;

  final Color? canvas;

  final Color? scrim;

  final BreakPalette? palette;

  final VoidCallback? onSkip;
  final bool strictMode;

  final bool showSkip;

  final double safeTopInset;

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

// Stand-in desktop shown behind transparent templates in settings previews.
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
