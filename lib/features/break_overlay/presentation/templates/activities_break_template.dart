import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/guided_breathing_widget.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/eye_sync_game_widget.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';

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
  late _Activity _selected;
  Key _activityKey = UniqueKey();

  late AnimationController _underlineController;
  late Animation<double> _underlineWidth;

  static const _accent = BreakOverlayTheme.accentShort;

  @override
  void initState() {
    super.initState();
    _selected = widget.breakInfo.type == BreakType.short
        ? _Activity.eyeSync
        : _Activity.breathing;
    _underlineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: _selected == _Activity.breathing ? 0.0 : 1.0,
    );
    _underlineWidth = _underlineController.drive(
      CurveTween(curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _underlineController.dispose();
    super.dispose();
  }

  void _switch(_Activity a) {
    if (a == _selected) return;
    setState(() {
      _selected = a;
      _activityKey = UniqueKey();
    });
    if (a == _Activity.breathing) {
      _underlineController.reverse();
    } else {
      _underlineController.forward();
    }
  }

  String _formatTime(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isShort = widget.breakInfo.type == BreakType.short;

    return ColoredBox(
      color: BreakOverlayTheme.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        isShort ? 'Quick break' : 'Long break',
                        style: TextStyle(
                          color: BreakOverlayTheme.textMuted,
                          fontSize: BreakOverlayTheme.labelFontSize,
                          fontWeight: FontWeight.w400,
                          fontFamily: BreakOverlayTheme.fontFamily,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatTime(widget.remainingSeconds),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                          fontFamily: BreakOverlayTheme.fontFamily,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  RepaintBoundary(
                    child: _TabSwitcher(
                      selected: _selected,
                      onSelect: _switch,
                      accent: _accent,
                      underlineWidth: _underlineWidth,
                    ),
                  ),
                  const SizedBox(height: 36),

                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
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
            ),
          ),
          if (!widget.settings.strictMode && widget.onSkip != null)
            Positioned(
              bottom: BreakOverlayTheme.skipBottom,
              right: BreakOverlayTheme.skipRight,
              child: GestureDetector(
                onTap: widget.onSkip,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: BreakOverlayTheme.textDim,
                      fontSize: BreakOverlayTheme.labelFontSize,
                      fontWeight: FontWeight.w400,
                      fontFamily: BreakOverlayTheme.fontFamily,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabSwitcher extends StatelessWidget {
  final _Activity selected;
  final void Function(_Activity) onSelect;
  final Color accent;
  final Animation<double> underlineWidth;

  const _TabSwitcher({
    required this.selected,
    required this.onSelect,
    required this.accent,
    required this.underlineWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Tab(
          label: 'Breathing',
          isSelected: selected == _Activity.breathing,
          accent: accent,
          onTap: () => onSelect(_Activity.breathing),
          underlineAnim: ReverseAnimation(underlineWidth),
        ),
        const SizedBox(width: 32),
        _Tab(
          label: 'Eye sync',
          isSelected: selected == _Activity.eyeSync,
          accent: accent,
          onTap: () => onSelect(_Activity.eyeSync),
          underlineAnim: underlineWidth,
        ),
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color accent;
  final VoidCallback onTap;
  final Animation<double> underlineAnim;

  const _Tab({
    required this.label,
    required this.isSelected,
    required this.accent,
    required this.onTap,
    required this.underlineAnim,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : BreakOverlayTheme.textDim,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                fontFamily: BreakOverlayTheme.fontFamily,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedBuilder(
              animation: underlineAnim,
              builder: (_, _) => Container(
                height: 2,
                width: 40 * underlineAnim.value,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
