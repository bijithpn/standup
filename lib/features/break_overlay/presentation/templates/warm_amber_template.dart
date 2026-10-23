import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

class WarmAmberTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const WarmAmberTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<WarmAmberTemplate> createState() => _WarmAmberTemplateState();
}

class _WarmAmberTemplateState extends State<WarmAmberTemplate>
    with SingleTickerProviderStateMixin {
  /// A sunset is always warm and blue-free, so this ignores the theme.
  static const BreakPalette _sunset = BreakPalette(
    canvas: Color(0xFF1A120A),
    canvasRaised: Color(0xFF2A1A0D),
    surface: Color(0xFF2A1A0D),
    border: Color(0x33D4A55A),
    track: Color(0x33D4A55A),
    textPrimary: Color(0xFFF3E9DA),
    textSecondary: Color(0xFFC9B79C),
    textMuted: Color(0xFFC9B79C),
    isDark: true,
  );

  /// Glow alpha breathes 26% <-> 32% over an 8s period.
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    breakSyncLoop(_breath, context, reverse: true);
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = BreakOverlayTheme.resolveAccent(
      widget.settings.templateAccentOverrides,
      'warm_amber',
      BreakOverlayTheme.amber,
    );
    final progress = breakProgress(
      widget.remainingSeconds,
      widget.totalSeconds,
    );
    final complete = widget.remainingSeconds <= 0 && widget.totalSeconds > 0;

    return ListenableBuilder(
      listenable: sl<StatsService>(),
      builder: (context, _) {
        final stats = sl<StatsService>().stats;
        final count = BreakPreviewScope.isPreview(context)
            ? 6
            : stats.breaksCompleted;

        return BreakScaffold(
          palette: _sunset,
          canvas: _sunset.canvas,
          // "Done for today" is this template's skip affordance.
          showSkip: false,
          onSkip: widget.onSkip,
          strictMode: widget.settings.strictMode,
          accent: accent,
          background: BreakSmoothProgress(
            progress: progress,
            builder: (context, anim) => TweenAnimationBuilder<double>(
              // Completion: the glow dims.
              tween: Tween(end: complete ? 1.0 : 0.0),
              duration: BreakMotion.slow,
              builder: (context, dim, _) => CustomPaint(
                painter: _SunsetPainter(
                  breath: _breath,
                  progress: anim,
                  glow: accent,
                  dim: dim,
                ),
              ),
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BreakEntrance(
                  child: ExcludeSemantics(
                    child: Icon(LucideIcons.sunset, size: 32, color: accent),
                  ),
                ),
                const SizedBox(height: 16),
                BreakEntrance(
                  delay: BreakEntrance.stagger(1),
                  scale: false,
                  child: Text(
                    'Winding down',
                    style: BreakOverlayTheme.title.copyWith(
                      color: _sunset.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                BreakEntrance(
                  delay: BreakEntrance.stagger(2),
                  scale: false,
                  child: BreakCountdown(
                    seconds: widget.remainingSeconds,
                    style: BreakOverlayTheme.hero,
                    color: breakClockColor(widget.settings, _sunset),
                  ),
                ),
                const SizedBox(height: 16),
                BreakEntrance(
                  delay: BreakEntrance.stagger(3),
                  scale: false,
                  child: Text(
                    '$count breaks today',
                    style: BreakOverlayTheme.body.copyWith(
                      color: _sunset.textSecondary,
                    ),
                  ),
                ),
                // The button keeps its original action (onSkip). In the real
                // overlay the chrome owns dismissal and passes no callback, so
                // the dead button is not drawn.
                if (widget.onSkip != null) ...[
                  const SizedBox(height: 32),
                  BreakEntrance(
                    delay: BreakEntrance.stagger(4),
                    scale: false,
                    child: IntrinsicWidth(
                      child: _AmberButton(
                        label: 'Done for today',
                        accent: accent,
                        onPressed: widget.onSkip!,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AmberButton extends StatefulWidget {
  final String label;
  final Color accent;
  final VoidCallback onPressed;

  const _AmberButton({
    required this.label,
    required this.accent,
    required this.onPressed,
  });

  @override
  State<_AmberButton> createState() => _AmberButtonState();
}

class _AmberButtonState extends State<_AmberButton> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: BreakMotion.fast,
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: Color.lerp(
                widget.accent,
                Colors.white,
                _hovered ? 0.12 : 0,
              ),
              shape: StadiumBorder(
                side: _focused
                    ? const BorderSide(color: Color(0xFFF3E9DA), width: 2)
                    : BorderSide.none,
              ),
            ),
            child: Text(
              widget.label,
              style: BreakOverlayTheme.body.copyWith(
                color: const Color(0xFF1A120A),
                fontWeight: FontWeight.w600,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SunsetPainter extends CustomPainter {
  final Animation<double> breath;
  final Animation<double> progress;
  final Color glow;
  final double dim;

  final Paint _sky = Paint();
  final Paint _glow = Paint();
  final Paint _disc = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);

  _SunsetPainter({
    required this.breath,
    required this.progress,
    required this.glow,
    required this.dim,
  }) : super(repaint: Listenable.merge([breath, progress]));

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    // The gradient is size-dependent, so rebuild it only when needed.
    _sky.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF1A120A), Color(0xFF3A2410)],
      stops: [0.0, 0.7],
    ).createShader(full);
    canvas.drawRect(full, _sky);

    // Horizon glow at (50%, 70%), sinking 2% of the height over the break.
    final center = Offset(
      size.width / 2,
      size.height * (0.70 + 0.02 * progress.value),
    );
    final a =
        (0.26 + 0.06 * Curves.easeInOutSine.transform(breath.value)) *
        (1 - 0.7 * dim);
    final radius = size.shortestSide * 0.85;
    _glow.shader = RadialGradient(
      colors: [
        glow.withValues(alpha: a),
        glow.withValues(alpha: 0),
      ],
    ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, _glow);

    _disc.color = glow.withValues(alpha: 0.09 * (1 - 0.7 * dim));
    canvas.drawCircle(center, size.shortestSide * 0.09, _disc);
  }

  @override
  bool shouldRepaint(covariant _SunsetPainter old) =>
      old.glow != glow || old.dim != dim;
}
