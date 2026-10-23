import 'dart:async';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

class MonoTimeTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const MonoTimeTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<MonoTimeTemplate> createState() => _MonoTimeTemplateState();
}

class _MonoTimeTemplateState extends State<MonoTimeTemplate> {
  /// A terminal is always dark phosphor-on-green-black, whatever the theme.
  static const Color _bg = Color(0xFF0B0F0A);
  static const BreakPalette _term = BreakPalette(
    canvas: _bg,
    canvasRaised: Color(0xFF121910),
    surface: Color(0xFF141A12),
    border: Color(0x33B5CC7A),
    track: Color(0x33B5CC7A),
    textPrimary: BreakOverlayTheme.phosphor,
    textSecondary: Color(0xFFA9BE72),
    textMuted: Color(0xFF8FA25F),
    isDark: true,
  );

  static const TextStyle _mono = TextStyle(
    // JetBrains Mono is not bundled; use the platform monospace.
    fontFamily: 'Menlo',
    fontFamilyFallback: [
      'JetBrains Mono',
      'SF Mono',
      'Consolas',
      'Courier New',
      'monospace',
    ],
    fontFeatures: [FontFeature.tabularFigures()],
  );

  Timer? _typeTimer;
  Timer? _blinkTimer;
  int _typed = 0;
  bool _typing = false;
  bool _cursorOn = true;
  bool _started = false;

  late final BreakKind _kind = BreakKind.of(widget.breakInfo);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (breakShouldFreeze(context)) return; // no typing, no blink
    _typing = true;
    // 20ms per character; the blink is a cheap 500ms timer, not a 60fps loop.
    _typeTimer = Timer.periodic(const Duration(milliseconds: 20), (t) {
      if (!mounted) return t.cancel();
      setState(() => _typed++);
      if (_typed > 200) {
        t.cancel();
        _typing = false;
      }
    });
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _cursorOn = !_cursorOn);
    });
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _blinkTimer?.cancel();
    super.dispose();
  }

  String _bar(double p) {
    const cells = 16;
    final filled = (p * cells).round().clamp(0, cells);
    return '${'█' * filled}${'░' * (cells - filled)}';
  }

  /// Reveals at most [_typed] characters across [lines].
  List<String> _reveal(List<String> lines) {
    if (!_typing) return lines;
    var left = _typed;
    return [
      for (final l in lines)
        () {
          final take = left.clamp(0, l.length);
          left -= take;
          return l.substring(0, take);
        }(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final phosphor = breakAccent(
      widget.settings,
      'mono_time',
      BreakOverlayTheme.phosphor,
    );
    final progress = breakProgress(
      widget.remainingSeconds,
      widget.totalSeconds,
    );
    final pct = (progress * 100).round();
    final complete = widget.remainingSeconds <= 0 && widget.totalSeconds > 0;
    final clockColor = breakClockColor(
      widget.settings,
      _term,
      fallback: phosphor,
    );

    final lines = _reveal([
      '[break] ${_kind.label.toLowerCase()}',
      '[${breakFormatTime(widget.remainingSeconds)}]',
      complete ? '[done]' : '${_bar(progress)} $pct%',
    ]);

    final glow = [
      Shadow(color: phosphor.withValues(alpha: 0.3), blurRadius: 12),
    ];

    return BreakScaffold(
      palette: _term,
      canvas: _bg,
      onSkip: widget.onSkip,
      strictMode: widget.settings.strictMode,
      accent: phosphor,
      background: const _CrtLayer(),
      child: Stack(
        children: [
          Positioned(
            left: 200,
            top: 280,
            child: Semantics(
              container: true,
              label:
                  'Break, ${_kind.label}, ${widget.remainingSeconds} seconds remaining, $pct percent complete',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lines[0],
                    style: _mono.copyWith(
                      fontSize: 15,
                      color: phosphor,
                      shadows: glow,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    lines[1],
                    style: _mono.copyWith(
                      fontSize: 56,
                      height: 1.1,
                      color: clockColor,
                      shadows: glow,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: lines[2]),
                        TextSpan(
                          text: '▋',
                          style: TextStyle(
                            color: _cursorOn
                                ? phosphor
                                : phosphor.withValues(alpha: 0),
                          ),
                        ),
                      ],
                    ),
                    style: _mono.copyWith(
                      fontSize: 15,
                      color: phosphor,
                      shadows: glow,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 40,
            bottom: 36,
            child: Semantics(
              label: 'Current time',
              excludeSemantics: true,
              child: Text(
                DateFormat('HH:mm').format(clock.now()),
                style: _mono.copyWith(fontSize: 12, color: _term.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Scanlines every 3px at 4% plus a soft vignette. Static, so it is rasterised
/// once by its repaint boundary.
class _CrtLayer extends StatelessWidget {
  const _CrtLayer();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _ScanlinePainter()),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 1.0,
                colors: [Colors.transparent, Color(0x59000000)],
                stops: [0.55, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  final Paint _p = Paint()
    ..color = const Color(0x0AB5CC7A)
    ..strokeWidth = 1;

  @override
  void paint(Canvas canvas, Size size) {
    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), _p);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanlinePainter old) => false;
}
