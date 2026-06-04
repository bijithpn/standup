import 'dart:math';
import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';

class QuietPillTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const QuietPillTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<QuietPillTemplate> createState() => _QuietPillTemplateState();
}

class _QuietPillTemplateState extends State<QuietPillTemplate>
    with SingleTickerProviderStateMixin {
  double? _x;
  double? _y;
  bool _drag = false;
  bool _hover = false;

  late AnimationController _pulse;

  static const _accent = Color(0xFF7EC8E3);
  static const double _closedW = 176;
  static const double _openW = 310;
  static const double _h = 56;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _snapCorner(double sw, double sh) {
    if (_x == null || _y == null) return;
    final corners = [
      Offset(16, 16),
      Offset(sw - _openW - 16, 16),
      Offset(16, sh - _h - 16),
      Offset(sw - _openW - 16, sh - _h - 16),
    ];
    Offset nearest = corners.first;
    double minD = double.infinity;
    for (final c in corners) {
      final d = sqrt(pow(_x! - c.dx, 2) + pow(_y! - c.dy, 2));
      if (d < minD) {
        minD = d;
        nearest = c;
      }
    }
    setState(() {
      _x = nearest.dx;
      _y = nearest.dy;
    });
  }

  String _formatTime(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  Widget _buildHoverContent() {
    return Row(
      children: [
        Container(
          width: 0.5,
          height: 24,
          color: Colors.white.withValues(alpha: 0.15),
          margin: const EdgeInsets.symmetric(horizontal: 10),
        ),
        Expanded(
          child: Text(
            widget.breakInfo.tip,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 10,
              fontFamily: 'Inter',
              height: 1.35,
            ),
          ),
        ),
        if (!widget.settings.strictMode && widget.onSkip != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: widget.onSkip,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Text(
                'Skip',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 11,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isShort = widget.breakInfo.type == BreakType.short;
    final label = isShort ? 'Eye rest' : 'Pause rest';

    return Material(
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _x ??= constraints.maxWidth - _openW - 16;
          _y ??= constraints.maxHeight - _h - 80;

          return Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: Colors.black.withValues(alpha: 0.38)),
              AnimatedPositioned(
                duration: _drag
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                left: _x,
                top: _y,
                child: MouseRegion(
                  onEnter: (_) => setState(() => _hover = true),
                  onExit: (_) => setState(() => _hover = false),
                  child: GestureDetector(
                    onPanStart: (_) => setState(() => _drag = true),
                    onPanUpdate: (d) {
                      setState(() {
                        _x = (_x! + d.delta.dx)
                            .clamp(0.0, constraints.maxWidth - _openW);
                        _y = (_y! + d.delta.dy)
                            .clamp(0.0, constraints.maxHeight - _h - 40);
                      });
                    },
                    onPanEnd: (_) {
                      setState(() => _drag = false);
                      _snapCorner(
                          constraints.maxWidth, constraints.maxHeight);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutBack,
                      width: _hover ? _openW : _closedW,
                      height: _h,
                      decoration: BoxDecoration(
                        color: const Color(0xE60F1015),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            AnimatedBuilder(
                              animation: _pulse,
                              builder: (_, _) => Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _accent.withValues(
                                    alpha: 0.3 + 0.55 * _pulse.value,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatTime(widget.remainingSeconds),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Inter',
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              label,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.38),
                                fontSize: 11,
                                fontFamily: 'Inter',
                              ),
                            ),
                            Expanded(
                              child: ClipRect(
                                child: AnimatedOpacity(
                                  opacity: _hover ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 150),
                                  child: _hover
                                      ? _buildHoverContent()
                                      : OverflowBox(
                                          alignment: Alignment.centerLeft,
                                          minWidth: 0,
                                          maxWidth: _openW,
                                          child: _buildHoverContent(),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
