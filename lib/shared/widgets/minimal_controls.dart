import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// Flat button with hover/press states used across settings pages.
class MinimalButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color? backgroundColor;
  final Color? disabledColor;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final bool isSecondary;
  final bool isGhost;

  const MinimalButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.backgroundColor,
    this.disabledColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.borderRadius,
    this.isSecondary = false,
    this.isGhost = false,
  });

  @override
  State<MinimalButton> createState() => _MinimalButtonState();
}

class _MinimalButtonState extends State<MinimalButton>
    with SingleTickerProviderStateMixin {
  bool _isHovering = false;
  bool _isPressed = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bool isDisabled = widget.onPressed == null;

    Color defaultBg = widget.isSecondary
        ? colors.surfaceContainerHigh
        : (widget.backgroundColor ?? AppTheme.primary);

    Color activeColor = isDisabled
        ? (widget.disabledColor ?? defaultBg.withValues(alpha: 0.5))
        : defaultBg;

    final double baseAlpha = defaultBg.a;

    if (widget.isGhost) {
      activeColor = !isDisabled && (_isPressed || _isHovering)
          ? AppTheme.hoverOverlay
          : Colors.transparent;
    } else if (!isDisabled) {
      if (_isPressed) {
        activeColor = activeColor.withValues(
          alpha: widget.isSecondary
              ? 0.15
              : (baseAlpha < 1.0 ? (baseAlpha * 1.5).clamp(0.0, 1.0) : 0.8),
        );
      } else if (_isHovering) {
        activeColor = activeColor.withValues(
          alpha: widget.isSecondary
              ? 0.1
              : (baseAlpha < 1.0 ? (baseAlpha * 1.8).clamp(0.0, 1.0) : 0.9),
        );
      }
    }

    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Semantics(
      button: true,
      enabled: !isDisabled,
      child: FocusableActionDetector(
        enabled: !isDisabled,
        onShowFocusHighlight: (focused) => setState(() => _isFocused = focused),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed?.call();
              return null;
            },
          ),
        },
        onShowHoverHighlight: (hovering) =>
            setState(() => _isHovering = hovering),
        mouseCursor: isDisabled
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: isDisabled
              ? null
              : (_) => setState(() => _isPressed = true),
          onTapUp: isDisabled
              ? null
              : (_) => setState(() => _isPressed = false),
          onTapCancel: isDisabled
              ? null
              : () => setState(() => _isPressed = false),
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            padding: widget.padding,
            constraints: const BoxConstraints(minHeight: 32),
            decoration: BoxDecoration(
              color: activeColor,
              borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
              border: _isFocused
                  ? Border.all(color: AppTheme.accentColor, width: 2)
                  : widget.isSecondary ||
                        (!widget.isGhost && widget.backgroundColor == null)
                  ? Border.all(color: AppTheme.border, width: 1)
                  : null,
            ),
            child: DefaultTextStyle(
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: widget.isGhost
                    ? (isDisabled ? AppTheme.textMuted : AppTheme.accent)
                    : widget.isSecondary
                    ? colors.onSurface
                    : AppTheme.onColor(defaultBg),
                fontFamily: 'Inter',
              ),
              child: Center(widthFactor: 1, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom slider supporting drag, keyboard nudging and accessibility semantics.
class MinimalSlider extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final Color? activeColor;

  const MinimalSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.min = 0.0,
    this.max = 1.0,
    this.activeColor,
  });

  @override
  State<MinimalSlider> createState() => _MinimalSliderState();
}

class _MinimalSliderState extends State<MinimalSlider> {
  bool _isHovering = false;
  bool _isDragging = false;
  bool _isFocused = false;
  double? _interactionValue;

  void _updateValue(Offset localPosition, double width) {
    if (width <= 0) return;
    final percent = (localPosition.dx / width).clamp(0.0, 1.0);
    final newValue = widget.min + (widget.max - widget.min) * percent;
    _interactionValue = newValue;
    widget.onChanged(newValue);
  }

  void _finishInteraction() {
    widget.onChangeEnd?.call(_interactionValue ?? widget.value);
    _interactionValue = null;
  }

  void _nudge(double fraction) {
    final next = (widget.value + (widget.max - widget.min) * fraction).clamp(
      widget.min,
      widget.max,
    );
    widget.onChanged(next);
    widget.onChangeEnd?.call(next);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp) {
      _nudge(0.05);
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowDown) {
      _nudge(-0.05);
    } else if (key == LogicalKeyboardKey.pageUp) {
      _nudge(0.2);
    } else if (key == LogicalKeyboardKey.pageDown) {
      _nudge(-0.2);
    } else if (key == LogicalKeyboardKey.home) {
      _nudge(-1);
    } else if (key == LogicalKeyboardKey.end) {
      _nudge(1);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.activeColor ?? AppTheme.primary;
    final percent = ((widget.value - widget.min) / (widget.max - widget.min))
        .clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Semantics(
          slider: true,
          value: '${(percent * 100).round()}%',
          increasedValue:
              '${((percent + 0.05).clamp(0.0, 1.0) * 100).round()}%',
          decreasedValue:
              '${((percent - 0.05).clamp(0.0, 1.0) * 100).round()}%',
          onIncrease: () => _nudge(0.05),
          onDecrease: () => _nudge(-0.05),
          child: Focus(
            onKeyEvent: _onKey,
            onFocusChange: (focused) => setState(() => _isFocused = focused),
            child: MouseRegion(
              onEnter: (_) => setState(() => _isHovering = true),
              onExit: (_) => setState(() => _isHovering = false),
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) {
                  setState(() => _isDragging = true);
                  _updateValue(details.localPosition, width);
                },
                onPanUpdate: (details) =>
                    _updateValue(details.localPosition, width),
                onPanEnd: (_) {
                  setState(() => _isDragging = false);
                  _finishInteraction();
                },
                onPanCancel: () {
                  setState(() => _isDragging = false);
                  _finishInteraction();
                },
                onTapDown: (details) =>
                    _updateValue(details.localPosition, width),
                onTapUp: (_) => _finishInteraction(),
                child: Container(
                  height: 24,
                  color: Colors.transparent,
                  child: Center(
                    child: SizedBox(
                      height: 4,
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: percent,
                            child: Container(
                              decoration: BoxDecoration(
                                color: activeColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          Positioned(
                            left: (width * percent) - 6,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              curve: Curves.easeOutCubic,
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceElevated,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      _isHovering || _isDragging || _isFocused
                                      ? activeColor
                                      : AppTheme.border,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Tap wrapper adding pointer cursor, focus and semantics to any child.
class TapTarget extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;
  final bool? selected;
  final String? semanticLabel;
  final HitTestBehavior behavior;

  const TapTarget({
    super.key,
    required this.onTap,
    required this.child,
    this.selected,
    this.semanticLabel,
    this.behavior = HitTestBehavior.deferToChild,
  });

  @override
  State<TapTarget> createState() => _TapTargetState();
}

class _TapTargetState extends State<TapTarget> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: enabled,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return null;
            },
          ),
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: _focused
                ? Border.all(
                    color: Theme.of(context).colorScheme.onSurface,
                    width: 2,
                  )
                : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: GestureDetector(
            behavior: widget.behavior,
            onTap: widget.onTap,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
