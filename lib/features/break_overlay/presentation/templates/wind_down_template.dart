import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

class WindDownTemplate extends StatefulWidget {
  const WindDownTemplate({super.key});

  @override
  State<WindDownTemplate> createState() => _WindDownTemplateState();
}

class _WindDownTemplateState extends State<WindDownTemplate>
    with SingleTickerProviderStateMixin {
  static const Color _gold = Color(0xFFC49A4A);

  /// The end of the day is always warm, whatever the theme.
  static const BreakPalette _evening = BreakPalette(
    canvas: Color(0xFF140D07),
    canvasRaised: Color(0xFF2E1C0C),
    surface: Color(0xFF2E1C0C),
    border: Color(0x1AFFFFFF),
    track: Color(0x33C49A4A),
    textPrimary: Color(0xFFF3E9DA),
    textSecondary: Color(0xFFC9B79C),
    textMuted: Color(0xFFC9B79C),
    isDark: true,
  );

  /// The glow breathes over a 10s period.
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
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

  static String _minutes(int m) {
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    final r = m % 60;
    return r == 0 ? '${h}h' : '${h}h ${r}m';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([sl<StatsService>(), sl<BreakController>()]),
      builder: (context, _) {
        final stats = sl<StatsService>().stats;
        final breakController = sl<BreakController>();

        // Only tiles that have data are shown ("Breaks taken" always is).
        final tiles = <({String label, String value})>[
          (label: 'Breaks taken', value: '${stats.breaksCompleted}'),
          if (stats.dailyUsageMinutes > 0)
            (label: 'Screen time', value: _minutes(stats.dailyUsageMinutes)),
          if (stats.currentStreak > 0)
            (label: 'Day streak', value: '${stats.currentStreak}'),
          if (stats.breaksSkipped > 0)
            (label: 'Skipped', value: '${stats.breaksSkipped}'),
        ];

        return BreakScaffold(
          palette: _evening,
          canvas: _evening.canvas,
          background: CustomPaint(painter: _GlowPainter(breath: _breath)),
          child: Center(
            child: BreakEntrance(
              scale: false,
              duration: const Duration(milliseconds: 1200),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: Icon(LucideIcons.sunset, size: 48, color: _gold),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Time to wind down',
                    textAlign: TextAlign.center,
                    style: BreakOverlayTheme.display.copyWith(
                      color: _evening.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < tiles.length; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        BreakEntrance(
                          delay: Duration(milliseconds: 80 * (i + 1)),
                          scale: false,
                          child: _Tile(
                            label: tiles[i].label,
                            value: tiles[i].value,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 32),
                  IntrinsicWidth(
                    child: _DoneButton(
                      gold: _gold,
                      onPressed: () => breakController.completeCurrentBreak(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final String value;

  const _Tile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label, $value',
      excludeSemantics: true,
      child: Container(
        width: 140,
        height: 88,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(BreakOverlayTheme.radiusMd),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: BreakOverlayTheme.title.copyWith(
                color: const Color(0xFFF3E9DA),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label.toUpperCase(),
              style: BreakOverlayTheme.micro.copyWith(
                color: const Color(0xFFC9B79C),
                fontSize: 11,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Done for today": autofocused, so Enter finishes the evening.
class _DoneButton extends StatefulWidget {
  final Color gold;
  final VoidCallback onPressed;

  const _DoneButton({required this.gold, required this.onPressed});

  @override
  State<_DoneButton> createState() => _DoneButtonState();
}

class _DoneButtonState extends State<_DoneButton> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Done for today',
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: FocusableActionDetector(
        autofocus: true,
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
            padding: const EdgeInsets.symmetric(horizontal: 32),
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: Color.lerp(widget.gold, Colors.white, _hovered ? 0.1 : 0),
              shape: StadiumBorder(
                side: _focused
                    ? const BorderSide(color: Color(0xFFF3E9DA), width: 2)
                    : BorderSide.none,
              ),
            ),
            child: Text(
              'Done for today',
              style: BreakOverlayTheme.body.copyWith(
                color: const Color(0xFF140D07),
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

class _GlowPainter extends CustomPainter {
  final Animation<double> breath;

  final Paint _sky = Paint();
  final Paint _glow = Paint();

  _GlowPainter({required this.breath}) : super(repaint: breath);

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    _sky.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF140D07), Color(0xFF2E1C0C)],
    ).createShader(full);
    canvas.drawRect(full, _sky);

    final a = 0.20 + 0.05 * Curves.easeInOutSine.transform(breath.value);
    _glow.shader = RadialGradient(
      center: const Alignment(0, 0.9),
      radius: 0.9,
      colors: [
        const Color(0xFFC49A4A).withValues(alpha: a),
        const Color(0xFFC49A4A).withValues(alpha: 0),
      ],
    ).createShader(full);
    canvas.drawRect(full, _glow);
  }

  @override
  bool shouldRepaint(covariant _GlowPainter old) => false;
}
