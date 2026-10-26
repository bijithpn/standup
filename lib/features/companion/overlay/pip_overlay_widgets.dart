part of 'pip_overlay_window.dart';

/// How one interaction is presented.
class _WishStyle {
  const _WishStyle(this.icon, this.label, this.hint);

  final IconData icon;

  /// One word, shown under the row for whichever button is in play.
  final String label;

  /// The longer form, for the tooltip.
  final String hint;
}

const Map<PetWish, _WishStyle> _wishStyles = <PetWish, _WishStyle>{
  PetWish.petting: _WishStyle(
    Icons.back_hand_rounded,
    'Pet',
    'Give it a scratch',
  ),
  PetWish.play: _WishStyle(
    Icons.sports_baseball_rounded,
    'Play',
    'Throw something for it',
  ),
  PetWish.treat: _WishStyle(Icons.cookie_rounded, 'Treat', 'Offer a treat'),
  PetWish.rest: _WishStyle(
    Icons.self_improvement_rounded,
    'Rest',
    'Start a break now',
  ),
};

/// The things a user can actually do to the companion, shown on hover.
///
/// The face says what the pet feels, and that was the whole of it before —
/// which left anyone seeing it for the first time with a wistful animal and no
/// idea that the answer was to click it. So the options appear under the pet
/// the moment the pointer arrives, with the one it would most appreciate right
/// now picked out in the accent colour, and a single word naming whichever
/// button is in play.
class _ActionBar extends StatefulWidget {
  const _ActionBar({
    required this.actions,
    required this.suggested,
    required this.background,
    required this.foreground,
    required this.onSelected,
  });

  /// The interactions the user has left switched on.
  final List<PetWish> actions;

  /// What the pet would most like. Highlighted, and prepended to the row when
  /// it is something the list does not already offer.
  final PetWish suggested;

  final Color background;
  final Color foreground;
  final ValueChanged<PetWish> onSelected;

  @override
  State<_ActionBar> createState() => _ActionBarState();
}

class _ActionBarState extends State<_ActionBar> {
  PetWish? _hovered;

  @override
  Widget build(BuildContext context) {
    final suggested = widget.suggested;
    final actions = <PetWish>[
      // Resting is the companion's own suggestion rather than a standing
      // option, so it is only ever here when it is being asked for.
      if (suggested == PetWish.rest) PetWish.rest,
      ...widget.actions,
    ];
    if (actions.isEmpty) return const SizedBox.shrink();

    // The hovered button wins the caption, because that is the one the user is
    // asking about. Otherwise it names what the pet wants.
    final labelled =
        _hovered ?? (actions.contains(suggested) ? suggested : null);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final action in actions) ...<Widget>[
              _ActionButton(
                style: _wishStyles[action]!,
                background: widget.background,
                foreground: widget.foreground,
                isSuggested: action == suggested,
                onEnter: () => setState(() => _hovered = action),
                onExit: () {
                  if (_hovered == action) setState(() => _hovered = null);
                },
                onTap: () => widget.onSelected(action),
              ),
              const SizedBox(width: 6),
            ],
          ]..removeLast(),
        ),
        SizedBox(
          height: 16,
          child: labelled == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _wishStyles[labelled]!.label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                      color: labelled == suggested
                          ? AppTheme.accent
                          : widget.foreground.withValues(alpha: 0.75),
                      shadows: const <Shadow>[
                        // The caption can land on anything from a dark card to
                        // a white desktop, so it carries its own contrast.
                        Shadow(blurRadius: 4, color: Color(0xCC000000)),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.style,
    required this.background,
    required this.foreground,
    required this.isSuggested,
    required this.onEnter,
    required this.onExit,
    required this.onTap,
  });

  final _WishStyle style;
  final Color background;
  final Color foreground;
  final bool isSuggested;
  final VoidCallback onEnter;
  final VoidCallback onExit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: style.hint,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => onEnter(),
        onExit: (_) => onExit(),
        child: _Pressable(
          label: style.hint,
          onTap: onTap,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: isSuggested
                  ? AppTheme.accent.withValues(alpha: 0.22)
                  : background,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSuggested
                    ? AppTheme.accent.withValues(alpha: 0.85)
                    : foreground.withValues(alpha: 0.14),
                width: isSuggested ? 1.4 : 1.0,
              ),
            ),
            child: Icon(
              style.icon,
              size: 15,
              color: isSuggested
                  ? AppTheme.accent
                  : foreground.withValues(alpha: 0.85),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small round control in the window chrome.
class _ChromeButton extends StatelessWidget {
  const _ChromeButton({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.tooltip,
    required this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final String tooltip;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: _Pressable(
        label: tooltip,
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive
                    ? AppTheme.accent.withValues(alpha: 0.6)
                    : foreground.withValues(alpha: 0.12),
              ),
            ),
            child: Icon(
              icon,
              size: 13,
              color: isActive
                  ? AppTheme.accent
                  : foreground.withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
    );
  }
}

/// The companion's name, and nothing else.
///
/// What it is feeling is on its face. Narrating that in a caption would say
/// the same thing twice and worse — a pet that has to tell you it is happy
/// is not a pet, it is a status bar.
class _NamePill extends StatelessWidget {
  const _NamePill({
    required this.name,
    required this.background,
    required this.foreground,
  });

  final String name;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final label = name.trim();
    if (label.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: foreground.withValues(alpha: 0.1)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
          color: foreground.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}

/// A top drag grip displaying a 2x4 dotted grid with grab mouse cursors.
class _DottedDragHandle extends StatefulWidget {
  const _DottedDragHandle({
    required this.foreground,
    required this.background,
    required this.onDragStart,
    required this.onDragEnd,
  });

  final Color foreground;
  final Color background;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  @override
  State<_DottedDragHandle> createState() => _DottedDragHandleState();
}

class _DottedDragHandleState extends State<_DottedDragHandle> {
  bool _isHandleHovered = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final dotColor = widget.foreground.withValues(
      alpha: _isDragging ? 0.95 : (_isHandleHovered ? 0.8 : 0.45),
    );

    return Tooltip(
      message: 'Drag to move companion',
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: _isDragging
            ? SystemMouseCursors.grabbing
            : SystemMouseCursors.grab,
        onEnter: (_) => setState(() => _isHandleHovered = true),
        onExit: (_) => setState(() => _isHandleHovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) {
            setState(() => _isDragging = true);
            widget.onDragStart();
          },
          onPanEnd: (_) {
            setState(() => _isDragging = false);
            widget.onDragEnd();
          },
          onPanCancel: () {
            setState(() => _isDragging = false);
            widget.onDragEnd();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _isHandleHovered || _isDragging
                  ? widget.background.withValues(alpha: 0.85)
                  : widget.background.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.foreground.withValues(
                  alpha: _isDragging ? 0.3 : (_isHandleHovered ? 0.2 : 0.1),
                ),
                width: 1.0,
              ),
            ),
            child: SizedBox(
              width: 22,
              height: 8,
              child: CustomPaint(painter: _DottedGridPainter(color: dotColor)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for a clean 2x4 dotted grid.
class _DottedGridPainter extends CustomPainter {
  const _DottedGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const int cols = 4;
    const int rows = 2;
    const double radius = 1.25;

    final double stepX = cols > 1 ? (size.width - 2 * radius) / (cols - 1) : 0;
    final double stepY = rows > 1 ? (size.height - 2 * radius) / (rows - 1) : 0;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final cx = radius + c * stepX;
        final cy = radius + r * stepY;
        canvas.drawCircle(Offset(cx, cy), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DottedGridPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// A tappable control that also works from the keyboard and to a screen
/// reader: focusable, activated by Enter or Space, announced as a button, and
/// ringed in the accent colour while focused.
class _Pressable extends StatefulWidget {
  const _Pressable({
    required this.label,
    required this.onTap,
    required this.child,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: FocusableActionDetector(
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: _focused
                  ? Border.all(color: AppTheme.accent, width: 1.5)
                  : null,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
