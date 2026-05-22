import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:standup/features/break_system/domain/break_model.dart';
import 'package:standup/features/settings/settings_model.dart';
import 'package:standup/features/companion/domain/cat_theme.dart';
import 'package:standup/features/companion/domain/cat_animation_state.dart';
import 'package:standup/features/break_overlay/presentation/widgets/companion_sprite_widget.dart';

class ProductivityHudTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const ProductivityHudTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<ProductivityHudTemplate> createState() =>
      _ProductivityHudTemplateState();
}

class _ProductivityHudTemplateState extends State<ProductivityHudTemplate>
    with SingleTickerProviderStateMixin {
  late AnimationController _hudScannerController;

  @override
  void initState() {
    super.initState();
    // Holographic sweep scanline controller
    _hudScannerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _hudScannerController.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final catTheme = CatTheme.getTheme(widget.settings.companionCatTheme);
    final overallProgress = widget.totalSeconds > 0
        ? (widget.remainingSeconds / widget.totalSeconds).clamp(0.0, 1.0)
        : 0.0;

    return Material(
      color: Colors.transparent,
      child: Container(
        color: const Color(0xFF090A0F),
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Neon Grid background pattern
              Positioned.fill(
                child: Opacity(
                  opacity: 0.02,
                  child: GridPaper(
                    color: const Color(0xFF00FFCC),
                    interval: 60,
                    divisions: 1,
                    subdivisions: 1,
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 30,
                ),
                child: Column(
                  children: [
                    // HUD Top System Header
                    _buildHudHeader(),

                    const Spacer(),

                    // Main 3-Column HUD Workspace
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left Column: Hydration & Eye rest progress indicators
                        Expanded(
                          flex: 3,
                          child: _buildLeftHudMetrics(overallProgress),
                        ),

                        // Center Column: Holographic Assistant
                        Expanded(
                          flex: 4,
                          child: _buildCenterAssistant(catTheme),
                        ),

                        // Right Column: Streak & Glowing activity path chart
                        Expanded(flex: 3, child: _buildRightHudStats()),
                      ],
                    ),

                    const Spacer(),

                    // HUD System Footer
                    _buildHudFooter(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHudHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF00FFCC), width: 1.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'SYS_ACTIVE',
                style: TextStyle(
                  color: Color(0xFF00FFCC),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Satoshi',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'BREAK_MODE_v2.05',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
                fontFamily: 'Satoshi',
              ),
            ),
          ],
        ),
        Text(
          DateFormat('yyyy-MM-dd / HH:mm:ss').format(DateTime.now()),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            fontFamily: 'Satoshi',
          ),
        ),
      ],
    );
  }

  Widget _buildLeftHudMetrics(double overallProgress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMetricCard(
          title: 'BREAK STATUS',
          value: _formatDuration(widget.remainingSeconds),
          progress: overallProgress,
          color: const Color(0xFF00E5FF),
        ),
        const SizedBox(height: 20),
        _buildMetricCard(
          title: 'HYDRATION TARGET',
          value: '80% (6/8 GLASSES)',
          progress: 0.75,
          color: const Color(0xFF00FFCC),
        ),
        const SizedBox(height: 20),
        _buildMetricCard(
          title: 'EYE STRAIN METRIC',
          value: 'CRITICAL WARNING',
          progress: 0.9,
          color: const Color(0xFFFF3366),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required double progress,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.01),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  fontFamily: 'Satoshi',
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Satoshi',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFamily: 'Satoshi',
            ),
          ),
          const SizedBox(height: 12),
          // HUD Custom Linear Meter bar
          Stack(
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCenterAssistant(CatTheme catTheme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Sci-fi decorative HUD circles
            Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF00FFCC).withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.05),
                  width: 1.5,
                ),
              ),
            ),

            // holographic sweeping scan line over companion
            ClipOval(
              child: SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CompanionSpriteWidget(
                      catTheme: catTheme,
                      animationState: CatAnimationState.breakMode,
                      scale: 3.8,
                    ),

                    // Vertical laser sweep line
                    AnimatedBuilder(
                      animation: _hudScannerController,
                      builder: (context, child) {
                        final yOffset =
                            -100 + (_hudScannerController.value * 200);
                        return Positioned(
                          top: yOffset + 100,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 2.0,
                            decoration: const BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFF00FFCC),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF00FFCC).withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF00FFCC).withValues(alpha: 0.15),
            ),
          ),
          child: const Text(
            'HOLOGRAPHIC ASSISTANT ONLINE',
            style: TextStyle(
              color: Color(0xFF00FFCC),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              fontFamily: 'Satoshi',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRightHudStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Streak Card
        Container(
          padding: const EdgeInsets.all(20),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.01),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF00FFCC).withValues(alpha: 0.15),
            ),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DAILY COMPLETED STREAK',
                style: TextStyle(
                  color: Color(0xFF888899),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  fontFamily: 'Satoshi',
                ),
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    CupertinoIcons.flame_fill,
                    color: Colors.orangeAccent,
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Text(
                    '5 STREAKS ACTIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Glowing line chart Container
        Container(
          height: 160,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.01),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SYSTEM ACTIVITY GRAPH',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  fontFamily: 'Satoshi',
                ),
              ),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: HudLineChartPainter(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHudFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'SECURE_MODE: ENABLED',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
            fontFamily: 'Satoshi',
          ),
        ),
        if (!widget.settings.strictMode && widget.onSkip != null)
          GestureDetector(
            onTap: widget.onSkip,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3366).withValues(alpha: 0.05),
                  border: Border.all(
                    color: const Color(0xFFFF3366).withValues(alpha: 0.3),
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  children: [
                    Text(
                      'TERMINATE_SESSION',
                      style: TextStyle(
                        color: Color(0xFFFF3366),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        fontFamily: 'Satoshi',
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(
                      CupertinoIcons.clear_thick,
                      size: 10,
                      color: Color(0xFFFF3366),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class HudLineChartPainter extends CustomPainter {
  const HudLineChartPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paintGrid = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1;

    // Draw simple background grid
    const int cols = 5;
    for (int i = 0; i <= cols; i++) {
      final x = (size.width / cols) * i;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paintGrid);
    }
    const int rows = 3;
    for (int i = 0; i <= rows; i++) {
      final y = (size.height / rows) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrid);
    }

    // Chart path points
    final points = [
      Offset(0, size.height * 0.85),
      Offset(size.width * 0.2, size.height * 0.5),
      Offset(size.width * 0.4, size.height * 0.75),
      Offset(size.width * 0.6, size.height * 0.3),
      Offset(size.width * 0.8, size.height * 0.45),
      Offset(size.width, size.height * 0.15),
    ];

    final path = Path()..moveTo(points.first.dx, points.first.dy);

    // Draw cubic bezier curve for smoother connections
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlX = (p0.dx + p1.dx) / 2;
      path.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    // Fill under path
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF00FFCC).withValues(alpha: 0.2),
          const Color(0xFF00FFCC).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // Line stroke paint
    final linePaint = Paint()
      ..color = const Color(0xFF00FFCC)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, linePaint);

    // Draw glowing node circles
    final nodePaint = Paint()
      ..color = const Color(0xFF00FFCC)
      ..style = PaintingStyle.fill;

    for (final p in points) {
      canvas.drawCircle(p, 3.5, nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
