import 'package:flutter/material.dart';
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

class _ActivitiesBreakTemplateState extends State<ActivitiesBreakTemplate> {
  late _Activity _selected;
  Key _activityKey = UniqueKey();
  final FocusNode _controlFocus = FocusNode(debugLabel: 'activity switch');

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
  }

  @override
  void dispose() {
    _controlFocus.dispose();
    super.dispose();
  }

  void _switch(_Activity a) {
    if (a == _selected) return;
    setState(() {
      _selected = a;
      _activityKey = UniqueKey();
    });
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
      child: Stack(
        children: [
          Positioned(
            top: 48,
            left: 64,
            right: 64,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSwitch(palette),
                const Spacer(),
                BreakCountdown(
                  seconds: widget.remainingSeconds,
                  style: BreakOverlayTheme.display,
                  color: breakClockColor(widget.settings, palette),
                ),
              ],
            ),
          ),
          Positioned.fill(
            top: 112,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 720,
                  maxHeight: 480,
                ),
                child: AnimatedSwitcher(
                  duration: BreakMotion.medium,
                  switchInCurve: BreakMotion.enter,
                  switchOutCurve: BreakMotion.enter,
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),
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
        ],
      ),
    );
  }

  Widget _buildSwitch(BreakPalette palette) {
    return Semantics(
      container: true,
      inMutuallyExclusiveGroup: true,
      child: Focus(
        focusNode: _controlFocus,
        onKeyEvent: _onKey,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Choice(
              label: 'Breathing',
              selected: _selected == _Activity.breathing,
              accent: _accent,
              onTap: () {
                _controlFocus.requestFocus();
                _switch(_Activity.breathing);
              },
            ),
            const SizedBox(width: 28),
            _Choice(
              label: 'Eye sync',
              selected: _selected == _Activity.eyeSync,
              accent: _accent,
              onTap: () {
                _controlFocus.requestFocus();
                _switch(_Activity.eyeSync);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _Choice({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = BreakPalette.of(context);
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: selected ? accent : Colors.transparent,
                ),
              ),
            ),
            child: Text(
              label,
              style: BreakOverlayTheme.body.copyWith(
                color: selected ? palette.textPrimary : palette.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
