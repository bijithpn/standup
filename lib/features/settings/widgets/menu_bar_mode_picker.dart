import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:breakmate/shared/theme/app_theme.dart';

/// Maps a picker mode to the persisted (trayIconStyle, menuBarStyle) pair.
({String iconStyle, String menuStyle}) menuBarModeToStyles(String mode) => (
  iconStyle: mode == 'companion' ? 'companion' : 'default',
  menuStyle: switch (mode) {
    'companion' => 'companion',
    'minimal' => 'icon',
    _ => mode,
  },
);

/// Inverse of [menuBarModeToStyles], tolerant of values older builds saved.
String menuBarModeFromStyles(String trayIconStyle, String menuBarStyle) {
  if (trayIconStyle == 'companion' || trayIconStyle == 'cat') {
    return 'companion';
  }
  return switch (menuBarStyle) {
    'progress' => 'progress',
    'focusdot' => 'focusdot',
    'countdown' => 'countdown',
    _ => 'minimal',
  };
}

/// Tiles that show each menu bar display option animating live, so the
/// choice is visible before it is picked.
class MenuBarModePicker extends StatefulWidget {
  const MenuBarModePicker({
    super.key,
    required this.modes,
    required this.selected,
    required this.onSelected,
  });

  /// Mode id -> label.
  final Map<String, String> modes;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  State<MenuBarModePicker> createState() => _MenuBarModePickerState();
}

class _MenuBarModePickerState extends State<MenuBarModePicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final e in widget.modes.entries)
            _Tile(
              label: e.value,
              selected: e.key == widget.selected,
              onTap: () => widget.onSelected(e.key),
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (_, _) => CustomPaint(
                  size: const Size(54, 36),
                  painter: _PreviewPainter(e.key, _ctrl.value),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 120,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: selected ? 0.09 : 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.accentColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 76,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: child,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? AppTheme.textPrimary : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter(this.mode, this.t);

  final String mode;

  /// 0..1 over the whole loop.
  final double t;

  static const _white = Color(0xFFFFFFFF);

  Color _accent(double p) => p < 0.5
      ? Color.lerp(const Color(0xFF34C759), const Color(0xFFFFCC00), p / 0.5)!
      : Color.lerp(
          const Color(0xFFFFCC00),
          const Color(0xFFFF453A),
          (p - 0.5) / 0.5,
        )!;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final progress = Curves.easeInOut.transform(t);
    final color = _accent(progress);
    final breathe = (1 - math.cos(t * 6 * math.pi * 2)) / 2; // 6 pulses
    final pulse = (t * 6) % 1.0;

    switch (mode) {
      case 'progress':
        const r = 11.0;
        final rect = Rect.fromCircle(center: c, radius: r);
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.5
            ..color = const Color(0xFF8E8E93).withValues(alpha: 0.55),
        );
        canvas.drawArc(
          rect,
          -math.pi / 2,
          math.pi * 2 * math.max(progress, 0.02),
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.5
            ..strokeCap = StrokeCap.round
            ..color = color,
        );
        canvas.drawCircle(c, 2.5 + breathe, Paint()..color = color);
      case 'focusdot':
        final core = 4.5 + 2.5 * progress + breathe * 0.6;
        const outer = 15.0;
        canvas.drawCircle(
          c,
          outer,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = color.withValues(alpha: 0.35),
        );
        final rt = Curves.easeOut.transform(pulse);
        canvas.drawCircle(
          c,
          core + 3.5 + rt * (outer - core - 5.5),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..color = color.withValues(alpha: 0.7 * (1 - rt)),
        );
        canvas.drawCircle(c, core, Paint()..color = color);
      case 'countdown':
        final secs = (25 * 60 * (1 - t)).round();
        final tp = TextPainter(
          text: TextSpan(
            text: '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}',
            style: const TextStyle(
              color: _white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
      case 'minimal':
        final badge = 22.0 + breathe * 2;
        final rr = RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: badge, height: badge),
          const Radius.circular(7),
        );
        canvas.drawRRect(rr, Paint()..color = color);
        canvas.drawCircle(c, 4, Paint()..color = _white);
      default: // companion: a small bobbing, blinking face
        final bob = math.sin(t * 6 * math.pi * 2) * 1.2;
        final f = c.translate(0, bob);
        final body = Paint()..color = const Color(0xFFFFB86B);
        canvas.drawCircle(f.translate(-8, -9), 4, body);
        canvas.drawCircle(f.translate(8, -9), 4, body);
        canvas.drawCircle(f, 12, body);
        final blink = (t * 6) % 1.0 > 0.9;
        final eye = Paint()..color = const Color(0xFF3A2A1A);
        for (final dx in [-4.5, 4.5]) {
          if (blink) {
            canvas.drawLine(
              f.translate(dx - 1.8, -1),
              f.translate(dx + 1.8, -1),
              eye..strokeWidth = 1.2,
            );
          } else {
            canvas.drawCircle(f.translate(dx, -1), 1.6, eye);
          }
        }
        canvas.drawCircle(f.translate(0, 3.5), 1.2, eye);
    }
  }

  @override
  bool shouldRepaint(_PreviewPainter old) => old.t != t || old.mode != mode;
}
