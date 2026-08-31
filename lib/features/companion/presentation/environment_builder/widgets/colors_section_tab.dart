import 'package:flutter/material.dart';
import 'package:breakmate/shared/shared.dart';
import 'package:breakmate/features/companion/domain/custom_environment_theme.dart';
import 'package:breakmate/features/companion/presentation/environment_builder/environment_builder_controller.dart';
import 'hsv_color_picker.dart';
import 'opacity_settings_section.dart';

class ColorsSectionTab extends StatefulWidget {
  final EnvironmentBuilderController controller;
  final CustomEnvironmentTheme draft;

  const ColorsSectionTab({
    super.key,
    required this.controller,
    required this.draft,
  });

  @override
  State<ColorsSectionTab> createState() => _ColorsSectionTabState();
}

class _ColorsSectionTabState extends State<ColorsSectionTab> {
  int _activeProperty = 0;
  late TextEditingController _hexController;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _hexController = TextEditingController(
      text: _colorToHex(_getCurrentColor()),
    );
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant ColorsSectionTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentVal = _getCurrentColor();
    if (!_focusNode.hasFocus) {
      _hexController.text = _colorToHex(currentVal);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _hexController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Color _getCurrentColor() {
    switch (_activeProperty) {
      case 0:
        return Color(widget.draft.groundTintArgb);
      case 1:
        return Color(widget.draft.cloudTintArgb);
      case 2:
        return Color(widget.draft.baseColorArgb);
      default:
        return Colors.white;
    }
  }

  void _updateCurrentColor(Color color) {
    switch (_activeProperty) {
      case 0:
        widget.controller.updateGroundTint(color);
        break;
      case 1:
        widget.controller.updateCloudTint(color);
        break;
      case 2:
        widget.controller.updateBaseColor(color);
        break;
    }
    if (!_focusNode.hasFocus) {
      _hexController.text = _colorToHex(color);
    }
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _submitHex();
    }
  }

  void _submitHex() {
    final color = _parseHexColor(_hexController.text);
    if (color != null) {
      _updateCurrentColor(color);
      _hexController.text = _colorToHex(color);
    } else {
      _hexController.text = _colorToHex(_getCurrentColor());
    }
  }

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).toUpperCase().padLeft(8, '0')}';
  }

  Color? _parseHexColor(String hexString) {
    var hex = hexString.replaceAll('#', '').trim();
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    if (hex.length != 8) return null;
    final val = int.tryParse(hex, radix: 16);
    if (val == null) return null;
    return Color(val);
  }

  List<Color> get _currentPresets {
    switch (_activeProperty) {
      case 0:
        return const [
          Color(0xFFFFFFFF),
          Color(0xFFD47A3B),
          Color(0xFFE0F7FA),
          Color(0xFFFFE082),
          Color(0xFFFFCC80),
          Color(0xFF263238),
          Color(0xFF90A4AE),
          Color(0xFF757575),
          Color(0xFF4CAF50),
          Color(0xFF3E2723),
        ];
      case 1:
        return const [
          Color(0xFFFFFFFF),
          Color(0xFFFFECB3),
          Color(0xFFE0F2F1),
          Color(0xFFFFF9C4),
          Color(0xFF37474F),
          Color(0xFFB0BEC5),
          Color(0xFFCFD8DC),
          Color(0xFFFFCDD2),
          Color(0xFFE1BEE7),
          Color(0xFFB2EBF2),
        ];
      case 2:
        return const [
          Color(0xFF2E2625),
          Color(0xFF5D4037),
          Color(0xFFECEFF1),
          Color(0xFFFFF8E1),
          Color(0xFFFFE0B2),
          Color(0xFF37474F),
          Color(0xFF455A64),
          Color(0xFF9E9E9E),
          Color(0xFF0D47A1),
          Color(0xFFE040FB),
        ];
      default:
        return const [Colors.white];
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = _getCurrentColor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPropertySelector(
          0,
          'Ground Tint',
          Color(widget.draft.groundTintArgb),
        ),
        const SizedBox(height: 8),
        _buildPropertySelector(
          1,
          'Cloud Tint',
          Color(widget.draft.cloudTintArgb),
        ),
        const SizedBox(height: 8),
        _buildPropertySelector(
          2,
          'Base Colour',
          Color(widget.draft.baseColorArgb),
        ),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.border, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _getPropertyName(_activeProperty),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      fontFamily: 'Inter',
                    ),
                  ),

                  Container(
                    width: 90,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.border, width: 0.5),
                    ),
                    child: TextField(
                      controller: _hexController,
                      focusNode: _focusNode,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        fontFamily:
                            'SFMono-Regular, Consolas, Courier, monospace',
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 4,
                        ),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _submitHex(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              HsvColorPicker(
                color: currentColor,
                onChanged: _updateCurrentColor,
              ),
              const SizedBox(height: 16),

              Text(
                'Presets',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _currentPresets.map((preset) {
                    final isSelected =
                        preset.toARGB32() == currentColor.toARGB32();
                    return GestureDetector(
                      onTap: () {
                        _updateCurrentColor(preset);
                        _hexController.text = _colorToHex(preset);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: preset,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.accent
                                : AppTheme.border,
                            width: isSelected ? 2.0 : 0.5,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Divider(height: 0.5, thickness: 0.5, color: AppTheme.border),
        ),

        Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Layer Opacities',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
              fontFamily: 'Inter',
            ),
          ),
        ),
        OpacitySettingsSection(
          draft: widget.draft,
          controller: widget.controller,
        ),
      ],
    );
  }

  String _getPropertyName(int active) {
    switch (active) {
      case 0:
        return 'Ground Tint';
      case 1:
        return 'Cloud Tint';
      case 2:
        return 'Base Colour';
      default:
        return '';
    }
  }

  Widget _buildPropertySelector(int idx, String name, Color color) {
    final isSelected = _activeProperty == idx;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeProperty = idx;
          _hexController.text = _colorToHex(color);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accent.withValues(alpha: 0.08)
              : AppTheme.surfaceCard.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: isSelected ? AppTheme.accent : AppTheme.border,
            width: isSelected ? 1.2 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.border, width: 0.5),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: AppTheme.textPrimary,
                  fontFamily: 'Inter',
                ),
              ),
            ),
            Text(
              _colorToHex(color),
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.textMuted,
                fontFamily: 'SFMono-Regular, Consolas, Courier, monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
