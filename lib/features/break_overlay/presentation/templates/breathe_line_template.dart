import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';

class BreatheLineTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const BreatheLineTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<BreatheLineTemplate> createState() => _BreatheLineTemplateState();
}

class _BreatheLineTemplateState extends State<BreatheLineTemplate>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _lineAnim;
  String _phaseText = 'Breathe in';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _lineAnim = Tween<double>(begin: 60, end: 240).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.addStatusListener((status) {
      if (!mounted) return;
      if (status == AnimationStatus.forward) {
        setState(() => _phaseText = 'Breathe in');
      } else if (status == AnimationStatus.reverse) {
        setState(() => _phaseText = 'Breathe out');
      }
    });
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatTime(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isShort = widget.breakInfo.type == BreakType.short;
    final breakName = isShort ? 'Eye rest' : 'Long break';
    final accent = widget.settings.clockFaceTextColorHex != 0xFFFFFFFF
        ? Color(widget.settings.clockFaceTextColorHex)
        : const Color(0xFF7EC8E3);

    return ColoredBox(
      color: const Color(0xFF0A0A0F),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _phaseText,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 28),
                RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _lineAnim,
                    builder: (_, _) => Container(
                       width: _lineAnim.value,
                       height: 1,
                       color: accent,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  _formatTime(widget.remainingSeconds),
                  style: TextStyle(
                    color: Color(widget.settings.clockFaceTextColorHex),
                    fontSize: 48,
                    fontWeight: FontWeight.w200,
                    fontFamily: 'Inter',
                    fontFeatures: const [FontFeature.tabularFigures()],
                    letterSpacing: -1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  breakName,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
          if (!widget.settings.strictMode && widget.onSkip != null)
            Positioned(
              bottom: 36,
              right: 40,
              child: GestureDetector(
                onTap: widget.onSkip,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Inter',
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
