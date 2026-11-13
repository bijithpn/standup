import 'package:flutter/material.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_helpers.dart';

/// mm:ss countdown text with a screen-reader label.
class BreakCountdown extends StatelessWidget {
  final int seconds;
  final TextStyle? style;
  final Color? color;
  final TextAlign textAlign;

  const BreakCountdown({
    super.key,
    required this.seconds,
    this.style,
    this.color,
    this.textAlign = TextAlign.center,
  });

  @override
  Widget build(BuildContext context) {
    final palette = BreakPalette.of(context);
    final base = style ?? BreakOverlayTheme.display;
    return Semantics(
      container: true,
      label: '$seconds seconds remaining',
      excludeSemantics: true,
      child: Text(
        breakFormatTime(seconds),
        textAlign: textAlign,
        maxLines: 1,
        style: base.copyWith(
          color: breakReadableColor(
            color ?? palette.textPrimary,
            palette.surface,
          ),
        ),
      ),
    );
  }
}

class BreakLabel extends StatelessWidget {
  final String text;
  final Color? color;
  final TextAlign textAlign;

  const BreakLabel(
    this.text, {
    super.key,
    this.color,
    this.textAlign = TextAlign.center,
  });

  @override
  Widget build(BuildContext context) {
    final palette = BreakPalette.of(context);
    return Text(
      text.toUpperCase(),
      textAlign: textAlign,
      style: BreakOverlayTheme.micro.copyWith(
        color: breakReadableColor(color ?? palette.textMuted, palette.surface),
      ),
    );
  }
}

class BreakTip extends StatelessWidget {
  final String text;
  final Color? color;
  final TextAlign textAlign;
  final double maxWidth;

  const BreakTip(
    this.text, {
    super.key,
    this.color,
    this.textAlign = TextAlign.center,
    this.maxWidth = 420,
  });

  @override
  Widget build(BuildContext context) {
    final palette = BreakPalette.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Text(
        text,
        textAlign: textAlign,
        style: BreakOverlayTheme.body.copyWith(
          color: breakReadableColor(
            color ?? palette.textSecondary,
            palette.surface,
          ),
        ),
      ),
    );
  }
}
