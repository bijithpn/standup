import 'package:flutter/material.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

class HsvColorPicker extends StatefulWidget {
  final Color color;
  final ValueChanged<Color> onChanged;

  const HsvColorPicker({
    super.key,
    required this.color,
    required this.onChanged,
  });

  @override
  State<HsvColorPicker> createState() => _HsvColorPickerState();
}

class _HsvColorPickerState extends State<HsvColorPicker> {
  late double _hue;
  late double _saturation;
  late double _value;
  Color? _lastColor;

  @override
  void initState() {
    super.initState();
    _syncHsv();
  }

  @override
  void didUpdateWidget(covariant HsvColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.color.toARGB32() != _lastColor?.toARGB32() &&
        widget.color.toARGB32() != oldWidget.color.toARGB32()) {
      _syncHsv();
    }
  }

  void _syncHsv() {
    final hsv = HSVColor.fromColor(widget.color);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
    _lastColor = widget.color;
  }

  void _updateColor() {
    final newColor = HSVColor.fromAHSV(
      1.0,
      _hue,
      _saturation,
      _value,
    ).toColor();
    _lastColor = newColor;
    widget.onChanged(newColor);
  }

  void _handleGridGesture(Offset localPosition, Size size) {
    setState(() {
      _saturation = (localPosition.dx / size.width).clamp(0.0, 1.0);
      _value = (1.0 - (localPosition.dy / size.height)).clamp(0.0, 1.0);
    });
    _updateColor();
  }

  void _handleHueGesture(Offset localPosition, double width) {
    setState(() {
      _hue = (localPosition.dx / width).clamp(0.0, 1.0) * 360.0;
    });
    _updateColor();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            const height = 130.0;
            final size = Size(width, height);

            final hueColor = HSVColor.fromAHSV(1.0, _hue, 1.0, 1.0).toColor();

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanDown: (details) =>
                  _handleGridGesture(details.localPosition, size),
              onPanUpdate: (details) =>
                  _handleGridGesture(details.localPosition, size),
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.border, width: 0.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd - 0.5),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.white, hueColor],
                            ),
                          ),
                        ),
                      ),

                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black],
                            ),
                          ),
                        ),
                      ),

                      Positioned(
                        left: (_saturation * width) - 8,
                        top: ((1.0 - _value) * height) - 8,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: widget.color,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 4,
                                spreadRadius: 0.5,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 14),

        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanDown: (details) =>
                  _handleHueGesture(details.localPosition, width),
              onPanUpdate: (details) =>
                  _handleHueGesture(details.localPosition, width),
              child: Container(
                height: 24,
                alignment: Alignment.center,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFF0000),
                        Color(0xFFFFFF00),
                        Color(0xFF00FF00),
                        Color(0xFF00FFFF),
                        Color(0xFF0000FF),
                        Color(0xFFFF00FF),
                        Color(0xFFFF0000),
                      ],
                    ),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: (_hue / 360.0) * width - 8,
                        top: -3,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.black26,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
