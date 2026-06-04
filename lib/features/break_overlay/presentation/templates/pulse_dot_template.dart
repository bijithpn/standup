import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';

class PulseDotTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const PulseDotTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<PulseDotTemplate> createState() => _PulseDotTemplateState();
}

class _PulseDotTemplateState extends State<PulseDotTemplate>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  static const _accent = Color(0xFF6EE7B7);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _opacity = Tween<double>(begin: 0.25, end: 0.55).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
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

    return ColoredBox(
      color: const Color(0xFF0A0A0F),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 36,
            right: 40,
            child: Text(
              DateFormat('HH:mm').format(DateTime.now()),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.22),
                fontSize: 12,
                fontWeight: FontWeight.w400,
                fontFamily: 'Inter',
              ),
            ),
          ),
          Center(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (_, _) => Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.scale(
                      scale: _scale.value,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _accent.withValues(alpha: _opacity.value),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(widget.remainingSeconds),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 52,
                            fontWeight: FontWeight.w200,
                            fontFamily: 'Inter',
                            fontFeatures: [FontFeature.tabularFigures()],
                            letterSpacing: -2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          breakName,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.33),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
