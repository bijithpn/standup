import 'package:flutter/material.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

// Renders a row of colour swatches with a "Custom" option that opens a full
// colour picker. Used for groundTint, cloudTint and baseColor fields.
class ColorPickerRow extends StatelessWidget {
  final String label;
  final Color selected;
  final ValueChanged<Color> onChanged;

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

  const ColorPickerRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              letterSpacing: -0.1,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final preset in _presets) ...[
                  _SwatchTile(
                    color: preset,
                    isSelected: preset.toARGB32() == selected.toARGB32(),
                    onTap: () => onChanged(preset),
                  ),
                  const SizedBox(width: 8),
                ],
                _CustomSwatch(current: selected, onChanged: onChanged),
              ],
            ),
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

class _CustomSwatch extends StatelessWidget {
  final Color current;
  final ValueChanged<Color> onChanged;

  const _CustomSwatch({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openPicker(context),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.border),
        ),
        child: const Icon(
          Icons.colorize_rounded,
          size: 14,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  void _openPicker(BuildContext context) {
    showDialog<Color>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => _HsvPickerDialog(initial: current),
    ).then((color) {
      if (color != null) onChanged(color);
    });
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
              _buildSlider(
                'Hue',
                _hsv.hue,
                0,
                360,
                (v) => setState(() => _hsv = _hsv.withHue(v)),
              ),
              const SizedBox(height: 8),
              _buildSlider(
                'Saturation',
                _hsv.saturation,
                0,
                1,
                (v) => setState(() => _hsv = _hsv.withSaturation(v)),
              ),
              const SizedBox(height: 8),
              _buildSlider(
                'Value',
                _hsv.value,
                0,
                1,
                (v) => setState(() => _hsv = _hsv.withValue(v)),
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
