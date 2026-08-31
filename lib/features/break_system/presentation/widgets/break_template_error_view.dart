import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/core/services/error_toast_service.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';

/// Displayed when a requested break template cannot be loaded or is invalid,
/// showing an informative message and toast instead of silently falling back.
class BreakTemplateErrorView extends StatefulWidget {
  final String templateName;
  final BreakModel breakInfo;
  final SettingsModel? settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const BreakTemplateErrorView({
    super.key,
    required this.templateName,
    required this.breakInfo,
    this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<BreakTemplateErrorView> createState() => _BreakTemplateErrorViewState();
}

class _BreakTemplateErrorViewState extends State<BreakTemplateErrorView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ErrorToastService.showError(
        'Template "${widget.templateName}" could not be loaded.',
      );
    });
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bool canSkip =
        widget.onSkip != null && !(widget.settings?.strictMode ?? false);

    return ColoredBox(
      color: BreakOverlayTheme.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
              constraints: const BoxConstraints(maxWidth: 440),
              decoration: BoxDecoration(
                color: const Color(0xFF141720),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.35),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.exclamationmark_triangle_fill,
                      color: Colors.redAccent,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Template Error',
                    style: TextStyle(
                      fontFamily: BreakOverlayTheme.fontFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: BreakOverlayTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Template "${widget.templateName}" could not be loaded.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: BreakOverlayTheme.fontFamily,
                      fontSize: 14,
                      color: BreakOverlayTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _formatTime(widget.remainingSeconds),
                    style: const TextStyle(
                      fontFamily: BreakOverlayTheme.fontFamily,
                      fontSize: 40,
                      fontWeight: FontWeight.w200,
                      color: BreakOverlayTheme.textPrimary,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.breakInfo.title,
                    style: const TextStyle(
                      fontFamily: BreakOverlayTheme.fontFamily,
                      fontSize: 12,
                      color: BreakOverlayTheme.textDim,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (canSkip)
            Positioned(
              bottom: BreakOverlayTheme.skipBottom,
              right: BreakOverlayTheme.skipRight,
              child: GestureDetector(
                onTap: widget.onSkip,
                child: const MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: BreakOverlayTheme.textDim,
                      fontSize: BreakOverlayTheme.labelFontSize,
                      fontWeight: FontWeight.w400,
                      fontFamily: BreakOverlayTheme.fontFamily,
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
