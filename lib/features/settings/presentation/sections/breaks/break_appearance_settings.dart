import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/utils/toast.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:breakmate/features/break_overlay/wellness/motion_kit.dart';
import 'package:breakmate/features/break_overlay/wellness/wellness_models.dart';
import 'package:breakmate/features/break_overlay/wellness/wellness_registry.dart';
import 'package:breakmate/features/break_overlay/wellness/wellness_template.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/features/settings/widgets/settings_group.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/shared/widgets/app_dropdown.dart';
import 'package:breakmate/shared/widgets/minimal_controls.dart';

part 'break_appearance_sections.dart';
part 'template_gallery.dart';

/// Settings > Break Templates: six-template gallery with one live preview, motion/sound/display controls (see the part files).
class BreakAppearanceSettings extends StatefulWidget {
  final SettingsModel settings;
  final ValueChanged<SettingsModel> onSave;

  const BreakAppearanceSettings({
    super.key,
    required this.settings,
    required this.onSave,
  });

  @override
  State<BreakAppearanceSettings> createState() =>
      _BreakAppearanceSettingsState();
}

class _BreakAppearanceSettingsState extends State<BreakAppearanceSettings> {
  late String _selectedTemplateId = migrateTemplateId(
    widget.settings.breakTemplate,
  );
  bool _compactPreview = true;
  double? _intensity;
  double? _volume;
  final int _liveStartMs = DateTime.now().millisecondsSinceEpoch;

  void _select(String id) => setState(() => _selectedTemplateId = id);

  void _setDrag({double? intensity, double? volume}) => setState(() {
    _intensity = intensity;
    _volume = volume;
  });

  @override
  void didUpdateWidget(covariant BreakAppearanceSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.breakTemplate != widget.settings.breakTemplate) {
      _selectedTemplateId = migrateTemplateId(widget.settings.breakTemplate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasChanges =
        _selectedTemplateId != migrateTemplateId(widget.settings.breakTemplate);
    final selected = wellnessTemplateById(_selectedTemplateId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader('Break templates'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final (label, compact) in const [
              ('Compact', true),
              ('Immersive', false),
            ])
              MinimalButton(
                isGhost: true,
                onPressed: () => setState(() => _compactPreview = compact),
                child: Text(
                  label,
                  style: TextStyle(
                    color: _compactPreview == compact
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
            Text(
              'Selected · ${selected.name}',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            Tooltip(
              message: 'Preview selected template',
              child: MinimalButton(
                isSecondary: true,
                onPressed: () => _showBreakTemplatePreview(_selectedTemplateId),
                child: const Text('Preview break'),
              ),
            ),
            Tooltip(
              message: 'Apply selected template',
              child: MinimalButton(
                onPressed: hasChanges
                    ? () {
                        widget.onSave(
                          widget.settings.copyWith(
                            breakTemplate: _selectedTemplateId,
                          ),
                        );
                        Toast.showSuccess(context, 'Template updated');
                      }
                    : null,
                child: const Text('Apply'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildGallery(),
        const SizedBox(height: 16),
        _buildLivePreview(context),
        const SizedBox(height: 24),
        ..._buildControls(),
        sectionHeader('Accessibility'),
        buildCard([
          toggleRow(
            'Reduce motion',
            'Freezes decorative animations everywhere',
            widget.settings.reduceMotion,
            (v) => widget.onSave(widget.settings.copyWith(reduceMotion: v)),
          ),
          divider(),
          toggleRow(
            'Larger text',
            'Bigger text in break screens and reminders',
            widget.settings.largeOverlayText,
            (v) => widget.onSave(widget.settings.copyWith(largeOverlayText: v)),
          ),
        ]),
      ],
    );
  }

  void _showBreakTemplatePreview(String templateId) {
    try {
      final controller = sl<BreakController>();
      controller.previewBreak(templateId: templateId);

      if (mounted) {
        Toast.showSuccess(context, 'Preview started');
      }
    } catch (e) {
      if (mounted) {
        Toast.showError(context, 'Failed to start preview: ${e.toString()}');
      }
    }
  }
}
