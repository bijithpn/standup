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
        const SizedBox(height: 8),
        Text(
          'Choose a scene and how it appears.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: true, label: Text('Compact')),
                ButtonSegment(value: false, label: Text('Immersive')),
              ],
              selected: {_compactPreview},
              onSelectionChanged: (v) =>
                  setState(() => _compactPreview = v.first),
            ),
            Text(
              'Selected · ${selected.name}',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            Tooltip(
              message: 'Preview selected template',
              child: MinimalButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                backgroundColor: AppTheme.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                onPressed: () => _showBreakTemplatePreview(_selectedTemplateId),
                child: Text(
                  'Preview break',
                  style: TextStyle(
                    color: AppTheme.accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            Tooltip(
              message: 'Apply selected template',
              child: MinimalButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                backgroundColor: AppTheme.accentColor,
                disabledColor: AppTheme.accentColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
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
                child: Text(
                  'Apply',
                  style: TextStyle(
                    color: AppTheme.onAccent.withValues(
                      alpha: hasChanges ? 1 : 0.5,
                    ),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildGallery(),
        const SizedBox(height: 16),
        _buildLivePreview(context),
        const SizedBox(height: 32),
        ..._buildControls(),
        const SizedBox(height: 32),
        sectionHeader('Accessibility'),
        buildCard([
          toggleRow(
            'Reduce motion',
            'Freeze decorative animations in break screens, reminders, the companion and the app.',
            widget.settings.reduceMotion,
            (v) => widget.onSave(widget.settings.copyWith(reduceMotion: v)),
          ),
          divider(),
          toggleRow(
            'Larger text',
            'Scale up text in break screens and reminders (and slightly in the app).',
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
        Toast.showSuccess(
          context,
          'Preview started! Break overlay will appear.',
        );
      }
    } catch (e) {
      if (mounted) {
        Toast.showError(context, 'Failed to start preview: ${e.toString()}');
      }
    }
  }
}
