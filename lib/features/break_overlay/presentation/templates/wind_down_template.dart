import 'package:flutter/material.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

class WindDownTemplate extends StatelessWidget {
  const WindDownTemplate({super.key});

  static const _palette = BreakPalette(
    canvas: Color(0xFF2A1A4A),
    canvasRaised: Color(0xFF3A2358),
    surface: Color(0xFF3A2358),
    border: Color(0x33FFE9C7),
    track: Color(0x33FFE9C7),
    textPrimary: Color(0xFFFFF1DC),
    textSecondary: Color(0xFFF2D3C4),
    textMuted: Color(0xFFD9B4B4),
    isDark: true,
  );
  static const Color _cream = Color(0xFFFFE9C7);

  static String _minutes(int m) {
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    final r = m % 60;
    return r == 0 ? '${h}h' : '${h}h ${r}m';
  }

  @override
  Widget build(BuildContext context) {
    const palette = _palette;
    return ListenableBuilder(
      listenable: Listenable.merge([sl<StatsService>(), sl<BreakController>()]),
      builder: (context, _) {
        final stats = sl<StatsService>().stats;
        final summary = [
          '${stats.breaksCompleted} breaks taken',
          if (stats.dailyUsageMinutes > 0)
            '${_minutes(stats.dailyUsageMinutes)} on screen',
          if (stats.currentStreak > 0) '${stats.currentStreak} day streak',
          if (stats.breaksSkipped > 0) '${stats.breaksSkipped} skipped',
        ].join('   ·   ');

        return BreakScaffold(
          palette: palette,
          canvas: palette.canvas,
          background: const CustomPaint(painter: _SunsetPainter()),
          child: Stack(
            children: [
              Positioned(
                left: 128,
                top: 128,
                right: 128,
                child: BreakEntrance(
                  scale: false,
                  duration: const Duration(milliseconds: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Time to\nwind down',
                        style: BreakOverlayTheme.serif.copyWith(
                          fontSize: 96,
                          height: 1.0,
                          fontWeight: FontWeight.w300,
                          letterSpacing: -2,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Semantics(
                        container: true,
                        label: summary,
                        excludeSemantics: true,
                        child: Text(
                          summary,
                          style: BreakOverlayTheme.body.copyWith(
                            fontSize: 17,
                            color: palette.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      IntrinsicWidth(
                        child: _DoneButton(
                          onPressed: () =>
                              sl<BreakController>().completeCurrentBreak(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Autofocused, so Enter finishes the evening.
class _DoneButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _DoneButton({required this.onPressed});

  @override
  State<_DoneButton> createState() => _DoneButtonState();
}

class _DoneButtonState extends State<_DoneButton> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final lit = _hovered || _focused;
    return Semantics(
      container: true,
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
            padding: const EdgeInsets.symmetric(horizontal: 36),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: WindDownTemplate._cream.withValues(alpha: lit ? 1 : 0.88),
              borderRadius: BorderRadius.circular(BreakOverlayTheme.radiusPill),
            ),
            child: Text(
              'Done for today',
              style: BreakOverlayTheme.body.copyWith(
                color: const Color(0xFF3A1F3F),
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
  const _SunsetPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final horizon = size.height * 0.72;
    final p = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFF2A1A4A),
          Color(0xFF7A3B73),
          Color(0xFFD9627A),
          Color(0xFFF5A85C),
        ],
        stops: const [0, 0.4, 0.7, 1],
      ).createShader(Rect.fromLTWH(0, 0, size.width, horizon));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, horizon), p);

    final sun = Offset(size.width * 0.7, horizon);
    final r = size.height * 0.2;
    p.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFFFE3A8), Color(0xFFFFB566)],
    ).createShader(Rect.fromCircle(center: sun, radius: r));
    canvas.drawCircle(sun, r, p);

    p.shader =
        const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4A2457), Color(0xFF1C1033)],
        ).createShader(
          Rect.fromLTWH(0, horizon, size.width, size.height - horizon),
        );
    canvas.drawRect(
      Rect.fromLTWH(0, horizon, size.width, size.height - horizon),
      p,
    );

    p.shader = null;
    for (var i = 0; i < 7; i++) {
      final t = i / 6;
      final w = r * (1.5 - 0.9 * t);
      final y = horizon + 10 + t * (size.height - horizon - 20) * 0.8;
      p.color = const Color(0xFFFFC27A).withValues(alpha: 0.55 - 0.4 * t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(sun.dx, y), width: w, height: 5),
          const Radius.circular(3),
        ),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SunsetPainter old) => false;
}
