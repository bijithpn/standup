import 'package:flutter/material.dart';
import 'package:breakmate/shared/shared.dart';
import 'package:breakmate/features/companion/domain/custom_environment_theme.dart';
import 'package:breakmate/features/companion/presentation/environment_builder/environment_builder_controller.dart';
import 'figma_value_input.dart';

class OpacitySettingsSection extends StatelessWidget {
  final CustomEnvironmentTheme draft;
  final EnvironmentBuilderController controller;

  const OpacitySettingsSection({
    super.key,
    required this.draft,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OpacitySliderRow(
          label: 'Sky/Background',
          value: draft.skyOpacity,
          onChanged: controller.updateSkyOpacity,
        ),
        OpacitySliderRow(
          label: 'Cloud Sprite',
          value: draft.cloudOpacity,
          onChanged: controller.updateCloudOpacity,
        ),
        OpacitySliderRow(
          label: 'Ground Tile',
          value: draft.groundOpacity,
          onChanged: controller.updateGroundOpacity,
        ),
        OpacitySliderRow(
          label: 'Mountain Left/Right',
          value: draft.mountainOpacity,
          onChanged: controller.updateMountainOpacity,
        ),
        OpacitySliderRow(
          label: 'Rock Left/Right',
          value: draft.rockOpacity,
          onChanged: controller.updateRockOpacity,
        ),
      ],
    );
  }
}

class OpacitySliderRow extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const OpacitySliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                fontFamily: 'Inter',
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 2,
                activeTrackColor: AppTheme.accent,
                inactiveTrackColor: AppTheme.border,
                thumbColor: AppTheme.accent,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: value.clamp(0.0, 1.0),
                min: 0.0,
                max: 1.0,
                onChanged: onChanged,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FigmaValueInput(
            value: value,
            min: 0.0,
            max: 1.0,
            step: 0.05,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class ScaleSliderRow extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const ScaleSliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const min = 0.1;
    const max = 3.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                fontFamily: 'Inter',
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 2,
                activeTrackColor: AppTheme.accent,
                inactiveTrackColor: AppTheme.border,
                thumbColor: AppTheme.accent,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FigmaValueInput(
            value: value,
            min: min,
            max: max,
            step: 0.10,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
