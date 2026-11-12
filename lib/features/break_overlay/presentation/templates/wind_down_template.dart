import 'package:flutter/material.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

class WindDownTemplate extends StatelessWidget {
  const WindDownTemplate({super.key});

  static const Color _gold = Color(0xFFC49A4A);

  static String _minutes(int m) {
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    final r = m % 60;
    return r == 0 ? '${h}h' : '${h}h ${r}m';
  }

  @override
  Widget build(BuildContext context) {
    const palette = BreakPalette.evening;
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
          background: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF140D07), Color(0xFF241608)],
              ),
            ),
          ),
          child: Center(
            child: BreakEntrance(
              scale: false,
              duration: const Duration(milliseconds: 1200),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Time to wind down',
                    textAlign: TextAlign.center,
                    style: BreakOverlayTheme.serif.copyWith(
                      fontSize: 52,
                      fontWeight: FontWeight.w300,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Semantics(
                    container: true,
                    label: summary,
                    excludeSemantics: true,
                    child: Text(
                      summary,
                      textAlign: TextAlign.center,
                      style: BreakOverlayTheme.body.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 56),
                  IntrinsicWidth(
                    child: _DoneButton(
                      gold: _gold,
                      onPressed: () =>
                          sl<BreakController>().completeCurrentBreak(),
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

/// Autofocused, so Enter finishes the evening.
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
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 32),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(BreakOverlayTheme.radiusPill),
              border: Border.all(
                color: widget.gold.withValues(alpha: lit ? 1 : 0.5),
              ),
            ),
            child: Text(
              'Done for today',
              style: BreakOverlayTheme.body.copyWith(
                color: BreakPalette.evening.textPrimary,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
