import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';
import 'package:breakmate/features/break_system/presentation/widgets/break_activity_graph.dart';

class IrisRestTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const IrisRestTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<IrisRestTemplate> createState() => _IrisRestTemplateState();
}

class _IrisRestTemplateState extends State<IrisRestTemplate>
    with SingleTickerProviderStateMixin {
  bool _showStreak = false;

  static const Color _good = Color(0xFF4ADE80);
  static const Color _fair = Color(0xFFF59E0B);
  static const Color _low = Color(0xFFEF4444);

  /// Dilate over 2.5s, constrict over 2.5s: a 5s cycle.
  late final AnimationController _iris = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2500),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (BreakPreviewScope.isPreview(context)) {
      _iris.value = 0.546; // opening ~80px
    } else if (BreakMotion.reduced(context)) {
      _iris.value = 0.6415; // opening ~90px, held
    } else {
      _iris.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _iris.dispose();
    super.dispose();
  }

  /// Last (up to) 10 days of break history, oldest first, padded to at
  /// least 2 entries so [BreakActivityGraph] never divides by zero when
  /// history is thin (e.g. a brand-new install).
  List<DailyStats> _recentDays(List<DailyStats> weeklyData) {
    final recent = weeklyData.length > 10
        ? weeklyData.sublist(weeklyData.length - 10)
        : weeklyData;
    if (recent.length >= 2) return recent;
    final placeholder = DailyStats(
      date: '0000-00-00',
      breaksCompleted: 0,
      breaksSkipped: 0,
      usageMinutes: 0,
    );
    return [for (var i = recent.length; i < 2; i++) placeholder, ...recent];
  }

  Color _colorForDay(DailyStats day) {
    final total = day.breaksCompleted + day.breaksSkipped;
    if (total == 0) return BreakOverlayTheme.nature;
    final rate = day.breaksCompleted / total;
    if (rate >= 0.75) return _good;
    if (rate >= 0.4) return _fair;
    return _low;
  }

  String _dayLabel(DailyStats day, bool isToday) {
    final total = day.breaksCompleted + day.breaksSkipped;
    if (total == 0) return '${isToday ? 'Today' : day.date}, no breaks yet';
    final pct = (day.breaksCompleted / total * 100).round();
    final grade = pct >= 75 ? 'good' : (pct >= 40 ? 'fair' : 'low');
    return '${isToday ? 'Today' : day.date}, $pct percent, $grade';
  }

  @override
  Widget build(BuildContext context) {
    final palette = BreakPalette.of(context);
    final accent = palette.accentOn(
      BreakOverlayTheme.resolveAccent(
        widget.settings.templateAccentOverrides,
        'iris_rest',
        _good,
      ),
    );
    final complete = breakIsComplete(
      context,
      widget.remainingSeconds,
      widget.totalSeconds,
    );
    final reduced = BreakMotion.reduced(context);

    return ListenableBuilder(
      listenable: sl<StatsService>(),
      builder: (context, _) {
        final recentDays = _recentDays(sl<StatsService>().stats.weeklyData);
        final dataPoints = recentDays.map((d) => d.breaksCompleted).toList();
        final pointColors = recentDays.map(_colorForDay).toList();

        return BreakScaffold(
          onSkip: widget.onSkip,
          strictMode: widget.settings.strictMode,
          accent: accent,
          background: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 0.8,
                colors: [accent.withValues(alpha: 0.05), Colors.transparent],
              ),
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 96,
                left: 64,
                right: 64,
                child: BreakEntrance(
                  scale: false,
                  child: Column(
                    children: [
                      Text(
                        'Rest Your Eyes, Refresh Your Mind',
                        textAlign: TextAlign.center,
                        style: BreakOverlayTheme.title.copyWith(
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Text(
                          'Gentle reminders to protect your vision '
                          'and boost focus. Take a moment - your '
                          'eyes deserve it.',
                          textAlign: TextAlign.center,
                          style: BreakOverlayTheme.body.copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 640 - 130,
                top: 370 - 130,
                child: BreakEntrance(
                  delay: BreakEntrance.stagger(1),
                  child: TweenAnimationBuilder<double>(
                    // Completion: the aperture opens fully and fades.
                    tween: Tween(end: complete ? 1.0 : 0.0),
                    duration: BreakMotion.slow,
                    curve: BreakMotion.enter,
                    builder: (context, finish, _) => RepaintBoundary(
                      child: CustomPaint(
                        size: const Size(260, 260),
                        painter: _AperturePainter(
                          open: _iris,
                          fixed:
                              reduced || BreakPreviewScope.isPreview(context),
                          accent: accent,
                          bladeA: Color.lerp(
                            palette.surface,
                            palette.isDark ? Colors.white : Colors.black,
                            0.08,
                          )!,
                          bladeB: palette.canvasRaised,
                          edge: palette.isDark
                              ? Colors.white.withValues(alpha: 0.16)
                              : const Color(0xFF1C1F24).withValues(alpha: 0.14),
                          housing: palette.border,
                          finish: finish,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 370 + 130 + 32,
                left: 0,
                right: 0,
                child: BreakEntrance(
                  delay: BreakEntrance.stagger(2),
                  scale: false,
                  child: BreakCountdown(
                    seconds: widget.remainingSeconds,
                    color: breakClockColor(widget.settings, palette),
                  ),
                ),
              ),
              // Compliance strip: dots, with the streak chart behind a toggle.
              Positioned(
                left: 0,
                right: 0,
                top: 596,
                child: BreakEntrance(
                  delay: BreakEntrance.stagger(3),
                  scale: false,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < recentDays.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Semantics(
                              label: _dayLabel(
                                recentDays[i],
                                i == recentDays.length - 1,
                              ),
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: pointColors[i],
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () =>
                            setState(() => _showStreak = !_showStreak),
                        style: TextButton.styleFrom(
                          foregroundColor: palette.textSecondary,
                          textStyle: BreakOverlayTheme.micro,
                        ),
                        child: Text(
                          _showStreak ? 'Hide streak' : 'Your streak',
                        ),
                      ),
                      if (_showStreak)
                        SizedBox(
                          width: 360,
                          height: 64,
                          child: BreakActivityGraph(
                            dataPoints: dataPoints,
                            pointColors: pointColors,
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

class _AperturePainter extends CustomPainter {
  final Animation<double> open;
  final bool fixed;
  final Color accent;
  final Color bladeA;
  final Color bladeB;
  final Color edge;
  final Color housing;
  final double finish;

  static const int _blades = 8;
  static const double _outer = 130;

  final List<Path> _paths = List.generate(_blades, (_) => Path());
  final Paint _fill = Paint();
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  final Paint _ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  final Paint _dot = Paint();

  _AperturePainter({
    required this.open,
    required this.fixed,
    required this.accent,
    required this.bladeA,
    required this.bladeB,
    required this.edge,
    required this.housing,
    required this.finish,
  }) : super(repaint: open) {
    _fill.shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [bladeA, bladeB],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: _outer));
    _stroke.color = edge;
    _ring.color = housing;
  }

  static Offset _p(double r, double a) =>
      Offset(math.cos(a) * r, math.sin(a) * r);

  @override
  void paint(Canvas canvas, Size size) {
    final eased = fixed ? 0.5 : Curves.easeInOutSine.transform(open.value);
    // Opening radius 40 -> 110px; completion opens it fully.
    final base = fixed ? 85.0 : 40 + 70 * eased;
    final r = base + (125 - base) * finish;
    final dotR = fixed ? 4.0 : (10 - 7 * eased) / 2;
    final twist = -(1 - (r - 40) / 85) * 0.45;
    final step = 2 * math.pi / _blades;
    final vertexR = r / math.cos(step / 2);

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.saveLayer(
      Rect.fromCircle(center: Offset.zero, radius: _outer + 4),
      Paint()..color = Color.fromRGBO(255, 255, 255, 1 - 0.85 * finish),
    );
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: _outer)),
    );

    for (var i = 0; i < _blades; i++) {
      final a = i * step + twist;
      // Inner edge is one side of the octagonal opening; the blade sweeps
      // outward past its neighbours so the leaves overlap like a real iris.
      final v0 = _p(vertexR, a - step / 2);
      final v1 = _p(vertexR, a + step / 2);
      // Far corners lie outside the housing (clipped), so the leaves always
      // cover the whole annulus however far the iris opens.
      final o1 = _p(_outer * 1.8, a + step / 2 + step * 1.1);
      final o0 = _p(_outer * 1.8, a - step / 2 - step * 0.1);
      _paths[i]
        ..reset()
        ..moveTo(v0.dx, v0.dy)
        ..lineTo(v1.dx, v1.dy)
        ..lineTo(o1.dx, o1.dy)
        ..lineTo(o0.dx, o0.dy)
        ..close();
      canvas.drawPath(_paths[i], _fill);
      canvas.drawPath(_paths[i], _stroke);
    }
    canvas.restore();
    canvas.drawCircle(Offset.zero, _outer, _ring);

    _dot.color = accent.withValues(alpha: 1 - 0.85 * finish);
    canvas.drawCircle(Offset.zero, dotR.clamp(1.5, 5.0), _dot);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AperturePainter old) =>
      old.fixed != fixed ||
      old.accent != accent ||
      old.bladeA != bladeA ||
      old.bladeB != bladeB ||
      old.edge != edge ||
      old.housing != housing ||
      old.finish != finish;
}
