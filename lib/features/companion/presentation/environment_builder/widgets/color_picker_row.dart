import 'package:flutter/material.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'hsv_color_picker.dart';

// Renders a row of colour swatches with a "Custom" option that opens a full
// colour picker. Used for groundTint, cloudTint and baseColor fields.
class ColorPickerRow extends StatefulWidget {
  final String label;
  final Color selected;
  final ValueChanged<Color> onChanged;

  const ColorPickerRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<ColorPickerRow> createState() => _ColorPickerRowState();
}

class _ColorPickerRowState extends State<ColorPickerRow> {
  late TextEditingController _hexController;
  late FocusNode _focusNode;

  static const List<Color> _presets = [
    Colors.white,
    Color(0xFFFFECB3), // warm gold
    Color(0xFFFFCC80), // amber
    Color(0xFFE57373), // dusk red
    Color(0xFF90CAF9), // sky blue
    Color(0xFFA5D6A7), // leaf green
    Color(0xFFCE93D8), // lavender
    Color(0xFF80CBC4), // teal
  ];

  @override
  void initState() {
    super.initState();
    _hexController = TextEditingController(text: _colorToHex(widget.selected));
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant ColorPickerRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected.toARGB32() != widget.selected.toARGB32() && !_focusNode.hasFocus) {
      _hexController.text = _colorToHex(widget.selected);
    }
  }

  @override
  void dispose() {
    _hexController.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _submitHex();
    }
  }

  void _submitHex() {
    final color = _parseHexColor(_hexController.text);
    if (color != null) {
      widget.onChanged(color);
      _hexController.text = _colorToHex(color);
    } else {
      _hexController.text = _colorToHex(widget.selected);
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

  void _openPicker(BuildContext context) {
    showDialog<Color>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => _HsvPickerDialog(initial: widget.selected),
    ).then((color) {
      if (color != null) {
        widget.onChanged(color);
        _hexController.text = _colorToHex(color);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              letterSpacing: -0.1,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Figma-style active Color button (clickable to open dialog picker)
              GestureDetector(
                onTap: () => _openPicker(context),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: widget.selected,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.border, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: widget.selected.withValues(alpha: 0.3),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.colorize_rounded,
                      size: 12,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Figma-style hex code input
              Container(
                width: 85,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.border, width: 0.5),
                ),
                child: TextField(
                  controller: _hexController,
                  focusNode: _focusNode,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    fontFamily: 'SFMono-Regular, Consolas, Courier, monospace',
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _submitHex(),
                ),
              ),
              const SizedBox(width: 12),
              // Vertical divider line
              Container(
                width: 1,
                height: 24,
                color: AppTheme.border,
              ),
              const SizedBox(width: 12),
              // Presets scrollable
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final preset in _presets) ...[
                        _SwatchTile(
                          color: preset,
                          isSelected: preset.toARGB32() == widget.selected.toARGB32(),
                          onTap: () {
                            widget.onChanged(preset);
                            _hexController.text = _colorToHex(preset);
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
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
}

class _SwatchTile extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _SwatchTile({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? AppTheme.accent
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: isSelected
            ? const Icon(Icons.check, size: 14, color: Colors.black)
            : null,
      ),
    );
  }
}



// Minimal HSV colour picker dialog — no external dependency required.
class _HsvPickerDialog extends StatefulWidget {
  final Color initial;

  const _HsvPickerDialog({required this.initial});

  @override
  State<_HsvPickerDialog> createState() => _HsvPickerDialogState();
}

class _HsvPickerDialogState extends State<_HsvPickerDialog> {
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initial);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        side: BorderSide(color: AppTheme.border),
      ),
      child: SizedBox(
        width: 280,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pick Colour',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 20),
              _buildPreview(),
              const SizedBox(height: 16),
              HsvColorPicker(
                color: _hsv.toColor(),
                onChanged: (newColor) {
                  setState(() {
                    final newHsv = HSVColor.fromColor(newColor);
                    _hsv = newHsv.withAlpha(_hsv.alpha);
                  });
                },
              ),
              const SizedBox(height: 8),
              _buildSlider(
                'Opacity',
                _hsv.alpha,
                0,
                1,
                (v) => setState(() => _hsv = _hsv.withAlpha(v)),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, _hsv.toColor()),
                    child: const Text(
                      'Apply',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final color = _hsv.toColor();
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '#${color.toARGB32().toRadixString(16).toUpperCase().padLeft(8, '0')}',
          style: const TextStyle(
            fontSize: 12,
            fontFamily: 'Inter',
            color: AppTheme.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
              fontFamily: 'Inter',
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              trackHeight: 4,
              activeTrackColor: AppTheme.accent,
              inactiveTrackColor: AppTheme.border,
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
