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

  static const BreakPalette _lavender = BreakPalette(
    canvas: Color(0xFFEDE7FF),
    canvasRaised: Color(0xFFF6F2FF),
    surface: Color(0xFFFFFFFF),
    border: Color(0x1F3B2F8F),
    track: Color(0x263B2F8F),
    textPrimary: Color(0xFF2B2370),
    textSecondary: Color(0xFF4B4290),
    textMuted: Color(0xFF6B63A8),
    isDark: false,
  );

  static const BreakPalette _stage = BreakPalette(
    canvas: Color(0xFF2B2A6E),
    canvasRaised: Color(0xFF35348A),
    surface: Color(0xFF3B3A96),
    border: Color(0x33FFFFFF),
    track: Color(0x33FFFFFF),
    textPrimary: Color(0xFFF4F2FF),
    textSecondary: Color(0xFFD3CEF5),
    textMuted: Color(0xFFB0AADF),
    isDark: true,
  );

  Color get _accent => BreakOverlayTheme.resolveAccent(
    widget.settings.templateAccentOverrides,
    'activities',
    const Color(0xFF6C5CE7),
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
    final isShort = widget.breakInfo.type == BreakType.short;

    return BreakScaffold(
      palette: _lavender,
      onSkip: widget.onSkip,
      strictMode: widget.settings.strictMode,
      accent: _accent,
      background: const CustomPaint(painter: _BlobsPainter()),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(72, 72, 72, 96),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 320,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BreakCountdown(
                    seconds: widget.remainingSeconds,
                    textAlign: TextAlign.left,
                    style: BreakOverlayTheme.display.copyWith(
                      fontSize: 84,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -3,
                      height: 1,
                    ),
                    color: breakClockColor(widget.settings, _lavender),
                  ),
                  const Spacer(),
                  _buildSwitch(),
                ],
              ),
            ),
            const SizedBox(width: 56),
            Expanded(
              child: BreakPaletteScope(
                palette: _stage,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _stage.canvas,
                    borderRadius: BorderRadius.circular(48),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(48),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 560,
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitch() {
    return Semantics(
      container: true,
      inMutuallyExclusiveGroup: true,
      child: Focus(
        focusNode: _controlFocus,
        onKeyEvent: _onKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Choice(
              label: 'Breathing',
              hint: 'Slow your breath',
              selected: _selected == _Activity.breathing,
              accent: _accent,
              onTap: () {
                _controlFocus.requestFocus();
                _switch(_Activity.breathing);
              },
            ),
            const SizedBox(height: 12),
            _Choice(
              label: 'Eye sync',
              hint: 'Follow the dot',
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
  final String hint;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _Choice({
    required this.label,
    required this.hint,
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
          child: AnimatedContainer(
            duration: BreakMotion.fast,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: BoxDecoration(
              color: selected ? accent : Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: BreakOverlayTheme.title.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hint,
                  style: BreakOverlayTheme.body.copyWith(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.85)
                        : palette.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BlobsPainter extends CustomPainter {
  const _BlobsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEDE7FF), Color(0xFFC9D3FF)],
        ).createShader(Offset.zero & size),
    );
    void blob(Offset c, double r, Color color) =>
        canvas.drawCircle(c, r, Paint()..color = color);
    blob(
      Offset(size.width * 0.04, size.height * 0.92),
      260,
      const Color(0x66B7A6F5),
    );
    blob(
      Offset(size.width * 0.96, size.height * 0.04),
      200,
      const Color(0x66FFFFFF),
    );
    blob(
      Offset(size.width * 0.22, size.height * 0.34),
      90,
      const Color(0x40FFFFFF),
    );
  }

  @override
  bool shouldRepaint(covariant _BlobsPainter old) => false;
}
