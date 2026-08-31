import 'dart:math';
import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';

class SoftFloatingWidgetTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const SoftFloatingWidgetTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<SoftFloatingWidgetTemplate> createState() =>
      _SoftFloatingWidgetTemplateState();
}

class _SoftFloatingWidgetTemplateState extends State<SoftFloatingWidgetTemplate>
    with SingleTickerProviderStateMixin {
  double? _x;
  double? _y;
  double? _lastWidth;
  double? _lastHeight;
  bool _isDragging = false;
  bool _isHovered = false;

  late AnimationController _pulseController;

  static const double _closedWidth = 224.0;
  static const double _openWidth = 310.0;
  static const double _height = 56.0;
  static const _accent = BreakOverlayTheme.accentShort;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _snapCorner(double sw, double sh) {
    if (_x == null || _y == null) return;
    const offset = 16.0;
    final corners = [
      Offset(offset, offset),
      Offset(sw - _openWidth - offset, offset),
      Offset(offset, sh - _height - offset),
      Offset(sw - _openWidth - offset, sh - _height - offset),
    ];
    Offset nearest = corners.first;
    double minDist = double.infinity;
    for (final c in corners) {
      final d = sqrt(pow(_x! - c.dx, 2) + pow(_y! - c.dy, 2));
      if (d < minDist) {
        minDist = d;
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
              fontFamily: BreakOverlayTheme.fontFamily,
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
                  color: BreakOverlayTheme.textDim,
                  fontSize: 11,
                  fontFamily: BreakOverlayTheme.fontFamily,
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
          if (_lastWidth != constraints.maxWidth ||
              _lastHeight != constraints.maxHeight) {
            if (_x != null && _lastWidth != null && _lastWidth! > 0) {
              _x = (_x! / _lastWidth!) * constraints.maxWidth;
            } else {
              _x = constraints.maxWidth - _openWidth - 16;
            }
            if (_y != null && _lastHeight != null && _lastHeight! > 0) {
              _y = (_y! / _lastHeight!) * constraints.maxHeight;
            } else {
              _y = constraints.maxHeight - _height - 80;
            }
            _lastWidth = constraints.maxWidth;
            _lastHeight = constraints.maxHeight;
          }

          final targetWidth = _isHovered ? _openWidth : _closedWidth;

          return Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: Colors.black.withValues(alpha: 0.4)),
              AnimatedPositioned(
                duration: _isDragging
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                left: _x,
                top: _y,
                child: MouseRegion(
                  onEnter: (_) => setState(() => _isHovered = true),
                  onExit: (_) => setState(() => _isHovered = false),
                  child: GestureDetector(
                    onPanStart: (_) => setState(() => _isDragging = true),
                    onPanUpdate: (d) {
                      setState(() {
                        _x = (_x! + d.delta.dx).clamp(
                          0.0,
                          constraints.maxWidth - targetWidth,
                        );
                        _y = (_y! + d.delta.dy).clamp(
                          0.0,
                          constraints.maxHeight - _height - 40,
                        );
                      });
                    },
                    onPanEnd: (_) {
                      setState(() => _isDragging = false);
                      _snapCorner(constraints.maxWidth, constraints.maxHeight);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutBack,
                      width: targetWidth,
                      height: _height,
                      decoration: BoxDecoration(
                        color: const Color(0xE60F1015),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (_, _) => Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _accent.withValues(
                                    alpha: 0.3 + 0.55 * _pulseController.value,
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
                                fontFamily: BreakOverlayTheme.fontFamily,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              label,
                              style: TextStyle(
                                color: BreakOverlayTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                fontFamily: BreakOverlayTheme.fontFamily,
                              ),
                            ),
                            if (_isHovered)
                              Expanded(
                                child: ClipRect(
                                  child: AnimatedOpacity(
                                    opacity: _isHovered ? 1.0 : 0.0,
                                    duration: const Duration(milliseconds: 150),
                                    child: _buildHoverContent(),
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
