import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/guided_breathing_widget.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/eye_sync_game_widget.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

enum _Activity { breathing, eyeSync }

class ActivitiesBreakTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const ActivitiesBreakTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<ActivitiesBreakTemplate> createState() =>
      _ActivitiesBreakTemplateState();
}

class _ActivitiesBreakTemplateState extends State<ActivitiesBreakTemplate>
    with SingleTickerProviderStateMixin {
  static const double _tabWidth = 168;
  static const double _controlHeight = 44;

  late _Activity _selected;
  Key _activityKey = UniqueKey();
  final FocusNode _controlFocus = FocusNode(debugLabel: 'activity tabs');

  /// Capsule position in tab units (0 = first tab). Unbounded so the spring
  /// can overshoot slightly.
  late final AnimationController _capsule;

  late final BreakKind _kind = BreakKind.of(widget.breakInfo);

  Color get _accent => BreakPalette.of(context).accentOn(
    BreakOverlayTheme.resolveAccent(
      widget.settings.templateAccentOverrides,
      'activities',
      _kind.accent,
    ),
  );

  @override
  void initState() {
    super.initState();
    _selected = widget.breakInfo.type == BreakType.short
        ? _Activity.eyeSync
        : _Activity.breathing;
    _capsule = AnimationController.unbounded(
      vsync: this,
      value: _selected.index.toDouble(),
    );
  }

  @override
  void dispose() {
    _capsule.dispose();
    _controlFocus.dispose();
    super.dispose();
  }

  void _switch(_Activity a) {
    if (a == _selected) return;
    setState(() {
      _selected = a;
      _activityKey = UniqueKey();
    });
    final target = a.index.toDouble();
    if (BreakMotion.reduced(context)) {
      _capsule.value = target;
    } else {
      _capsule.animateWith(
        SpringSimulation(
          BreakMotion.spring,
          _capsule.value,
          target,
          _capsule.velocity,
        ),
      );
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _switch(_Activity.breathing);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _switch(_Activity.eyeSync);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final palette = BreakPalette.of(context);
    final isShort = widget.breakInfo.type == BreakType.short;

    return BreakScaffold(
      onSkip: widget.onSkip,
      strictMode: widget.settings.strictMode,
      accent: _accent,
      background: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 0.9,
            colors: [_accent.withValues(alpha: 0.06), Colors.transparent],
          ),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 48,
            left: 64,
            right: 64,
            child: Row(
              children: [
                BreakLabel(_kind.label, textAlign: TextAlign.left),
                const Spacer(),
                BreakCountdown(
                  seconds: widget.remainingSeconds,
                  style: BreakOverlayTheme.title,
                  color: breakClockColor(widget.settings, palette),
                ),
              ],
            ),
          ),
          Positioned(
            top: 112,
            left: 0,
            right: 0,
            child: Center(child: _buildControl(palette)),
          ),
          Positioned(
            top: 112 + _controlHeight + 32,
            left: 0,
            right: 0,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 720,
                  maxHeight: 440,
                ),
                child: SizedBox(
                  height: 440,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: BreakMotion.medium,
                      switchInCurve: BreakMotion.enter,
                      switchOutCurve: BreakMotion.enter,
                      transitionBuilder: (child, anim) {
                        final incoming = child.key == _activityKey;
                        final reduced = BreakMotion.reduced(context);
                        final dx = reduced ? 0.0 : 12 / 720;
                        return FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: Offset(incoming ? dx : -dx, 0),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        );
                      },
                      child: _selected == _Activity.breathing
                          ? GuidedBreathingWidget(
                              key: _activityKey,
                              targetCycles: isShort ? 2 : 4,
                            )
                          : EyeSyncGameWidget(
                              key: _activityKey,
                              targetSessions: isShort ? 2 : 3,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControl(BreakPalette palette) {
    return Semantics(
      container: true,
      inMutuallyExclusiveGroup: true,
      child: Focus(
        focusNode: _controlFocus,
        onKeyEvent: _onKey,
        child: ListenableBuilder(
          listenable: _controlFocus,
          builder: (context, _) {
            final focused = _controlFocus.hasFocus;
            return ClipRRect(
              borderRadius: BorderRadius.circular(BreakOverlayTheme.radiusPill),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: BreakOverlayTheme.glassBlur,
                  sigmaY: BreakOverlayTheme.glassBlur,
                ),
                child: Container(
                  height: _controlHeight,
                  padding: const EdgeInsets.all(4),
                  decoration: ShapeDecoration(
                    color: palette.isDark
                        ? Colors.white.withValues(alpha: 0.10)
                        : Colors.black.withValues(alpha: 0.06),
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: focused ? _accent : palette.border,
                        width: focused ? 2 : 1,
                      ),
                    ),
                  ),
                  child: SizedBox(
                    width: _tabWidth * 2,
                    child: Stack(
                      children: [
                        RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: _capsule,
                            builder: (context, _) => Transform.translate(
                              offset: Offset(_capsule.value * _tabWidth, 0),
                              child: Container(
                                width: _tabWidth,
                                decoration: ShapeDecoration(
                                  color: _accent.withValues(alpha: 0.22),
                                  shape: const StadiumBorder(),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            _Tab(
                              label: 'Breathing',
                              selected: _selected == _Activity.breathing,
                              onTap: () {
                                _controlFocus.requestFocus();
                                _switch(_Activity.breathing);
                              },
                            ),
                            _Tab(
                              label: 'Eye sync',
                              selected: _selected == _Activity.eyeSync,
                              onTap: () {
                                _controlFocus.requestFocus();
                                _switch(_Activity.eyeSync);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Tab extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = BreakPalette.of(context);
    final color = widget.selected
        ? palette.textPrimary
        : (_hovered ? palette.textSecondary : palette.textMuted);
    return Semantics(
      container: true,
      button: true,
      selected: widget.selected,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: SizedBox(
            width: _ActivitiesBreakTemplateState._tabWidth,
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: BreakMotion.fast,
                style: BreakOverlayTheme.body.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                ),
                child: Text(widget.label),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
