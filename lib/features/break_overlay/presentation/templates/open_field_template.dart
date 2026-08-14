import 'dart:io';
import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';

class OpenFieldTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const OpenFieldTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<OpenFieldTemplate> createState() => _OpenFieldTemplateState();
}

class _OpenFieldTemplateState extends State<OpenFieldTemplate> {
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant OpenFieldTemplate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.customImagePath != widget.settings.customImagePath) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    final path = widget.settings.customImagePath;
    final isCustomEnabled = path != null && !path.startsWith('disabled:');
    final actualPath = (path != null && path.startsWith('disabled:'))
        ? path.substring(9)
        : path;

    if (isCustomEnabled &&
        actualPath != null &&
        actualPath != 'default_path' &&
        File(actualPath).existsSync()) {
      setState(() {
        _imagePath = actualPath;
      });
    } else {
      setState(() {
        _imagePath = null;
      });
    }
  }

  String _formatTime(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isShort = widget.breakInfo.type == BreakType.short;
    final breakTitle = isShort ? 'Eye rest' : 'Long break';

    Widget background;
    if (_imagePath != null) {
      background = Image.file(
        File(_imagePath!),
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
      );
    } else {
      background = const ColoredBox(color: BreakOverlayTheme.background);
    }

    return ColoredBox(
      color: BreakOverlayTheme.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(child: background),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xBF000000)],
                stops: [0.3, 1.0],
              ),
            ),
          ),
          Column(
            children: [
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      breakTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                        fontFamily: BreakOverlayTheme.fontFamily,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatTime(widget.remainingSeconds),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: BreakOverlayTheme.timerFontSizeLg,
                        fontWeight: FontWeight.w200,
                        fontFamily: BreakOverlayTheme.fontFamily,
                        fontFeatures: [FontFeature.tabularFigures()],
                        letterSpacing: -2,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 380,
                      child: Text(
                        widget.breakInfo.tip,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          fontFamily: BreakOverlayTheme.fontFamily,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  children: [
                    const Spacer(),
                    if (!widget.settings.strictMode && widget.onSkip != null)
                      GestureDetector(
                        onTap: widget.onSkip,
                        child: MouseRegion(
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
                  ],
                ),
              ),
              const SizedBox(height: 36),
            ],
          ),
        ],
      ),
    );
  }
}
