import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/companion/domain/custom_environment_theme.dart';
import 'package:breakmate/features/companion/services/custom_environment_repository.dart';
import 'package:breakmate/shared/shared.dart';
import 'environment_builder_controller.dart';
import 'widgets/env_preview_panel.dart';
import 'widgets/asset_picker_section.dart';
import 'widgets/color_picker_row.dart';
import 'widgets/code_output_sheet.dart';
import 'package:breakmate/features/companion/domain/custom_environment_layer.dart';

class EnvironmentBuilderPage extends StatelessWidget {
  const EnvironmentBuilderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EnvironmentBuilderController(
        repository: sl<CustomEnvironmentRepository>(),
      ),
      child: const _EnvironmentBuilderBody(),
    );
  }
}

class _EnvironmentBuilderBody extends StatelessWidget {
  const _EnvironmentBuilderBody();

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const DesktopDragScrollBehavior(),
      child: Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: _buildAppBar(context),
        body: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 800) {
              return _WideLayout();
            }
            return _NarrowLayout();
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final controller = context.read<EnvironmentBuilderController>();
    return PreferredSize(
      preferredSize: const Size.fromHeight(76),
      child: Container(
        margin: const EdgeInsets.only(top: 20),
        child: AppBar(
          backgroundColor: AppTheme.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,

          leading: IconButton(
            icon: const Icon(CupertinoIcons.chevron_left, size: 18),
            color: AppTheme.textSecondary,
            onPressed: () => Navigator.pop(context),
            tooltip: 'Back',
          ),
          titleSpacing: 0,

          title: const Text(
            'Environment Builder',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              letterSpacing: -0.2,
              fontFamily: 'Inter',
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(0.5),
            child: Container(height: 0.5, color: AppTheme.border),
          ),
          actions: [
            if (kDebugMode)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: TextButton.icon(
                  icon: const Icon(Icons.code_rounded, size: 14),
                  label: const Text('Get Code'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.warning,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                    ),
                  ),
                  onPressed: () => CodeOutputSheet.show(context, controller),
                ),
              ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _WideLayout extends StatelessWidget {
  const _WideLayout();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 55, child: _PickerPanel()),
        Container(width: 0.5, color: AppTheme.border),

        Expanded(flex: 45, child: _PreviewPanel()),
      ],
    );
  }
}

class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Consumer<EnvironmentBuilderController>(
              builder: (_, ctrl, _) => EnvPreviewPanel(theme: ctrl.draft),
            ),
          ),
        ),
        const Divider(height: 0.5, thickness: 0.5, color: AppTheme.border),
        Expanded(child: _PickerPanel()),
      ],
    );
  }
}

class _PickerPanel extends StatefulWidget {
  const _PickerPanel();

  @override
  State<_PickerPanel> createState() => _PickerPanelState();
}

class _TabItem {
  final IconData icon;
  final String label;
  const _TabItem(this.icon, this.label);
}

class _PickerPanelState extends State<_PickerPanel> {
  int _activeTab = 0;
  String _selectedToyKey = 'tennis_ball';
  String _selectedFoodKey = 'carrot';

  static const List<_TabItem> _tabs = [
    _TabItem(CupertinoIcons.photo, 'Canvas'),
    _TabItem(CupertinoIcons.color_filter, 'Tints & Blend'),
    _TabItem(CupertinoIcons.layers, 'Layers'),
    _TabItem(CupertinoIcons.paw, 'NPCs & Wildlife'),
    _TabItem(CupertinoIcons.bookmark, 'Saved Themes'),
  ];

  String _getToyLabel(String key) {
    switch (key) {
      case 'tennis_ball':
        return 'Tennis Ball';
      case 'base_ball':
        return 'Baseball';
      case 'basket_ball':
        return 'Basketball';
      case 'football':
        return 'Football';
      default:
        return 'Toy';
    }
  }

  String _getFoodLabel(String key) {
    switch (key) {
      case 'carrot':
        return 'Carrot / Snack';
      case 'bone':
        return 'Bone';
      default:
        return 'Food';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<EnvironmentBuilderController>();
    final d = ctrl.draft;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildVerticalTabs(),
        Container(width: 0.5, color: AppTheme.border),
        Expanded(
          child: ctrl.isLoadingAssets
              ? const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppTheme.accent,
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: _buildContent(ctrl, d),
                ),
        ),
      ],
    );
  }

  Widget _buildVerticalTabs() {
    return Container(
      width: 76,
      decoration: const BoxDecoration(color: AppTheme.surfaceCard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(_tabs.length, (idx) {
          final tab = _tabs[idx];
          final isSelected = _activeTab == idx;
          return GestureDetector(
            onTap: () => setState(() => _activeTab = idx),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: isSelected ? AppTheme.accent : Colors.transparent,
                    width: 3,
                  ),
                ),
                color: isSelected
                    ? AppTheme.accent.withValues(alpha: 0.08)
                    : Colors.transparent,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    tab.icon,
                    size: 18,
                    color: isSelected
                        ? AppTheme.accent
                        : AppTheme.textSecondary,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tab.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildContent(
    EnvironmentBuilderController ctrl,
    CustomEnvironmentTheme d,
  ) {
    switch (_activeTab) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _categoryLabel('Background & Sky'),
            AssetPickerSection(
              label: 'Sky / Background',
              paths: ctrl.skyPaths,
              selectedPath: d.skyPath,
              onSelected: ctrl.updateSky,
            ),
            AssetPickerSection(
              label: 'Ground Tile',
              paths: ctrl.groundPaths,
              selectedPath: d.groundPath,
              onSelected: ctrl.updateGround,
            ),
            Padding(
              padding: const EdgeInsets.only(
                top: 4,
                bottom: 16,
                left: 4,
                right: 4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tile Ground Texture',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                          fontFamily: 'Inter',
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Repeat texture or stretch as one image',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                  CupertinoSwitch(
                    value: d.isGroundTiled,
                    activeTrackColor: AppTheme.accent,
                    onChanged: ctrl.updateIsGroundTiled,
                  ),
                ],
              ),
            ),
            AssetPickerSection(
              label: 'Cloud Sprite',
              paths: ['none', ...ctrl.cloudPaths],
              selectedPath: d.cloudPath,
              onSelected: ctrl.updateCloud,
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _categoryLabel('Tints & Colours'),
            ColorPickerRow(
              label: 'Ground Tint',
              selected: Color(d.groundTintArgb),
              onChanged: ctrl.updateGroundTint,
            ),
            ColorPickerRow(
              label: 'Cloud Tint',
              selected: Color(d.cloudTintArgb),
              onChanged: ctrl.updateCloudTint,
            ),
            ColorPickerRow(
              label: 'Base Colour',
              selected: Color(d.baseColorArgb),
              onChanged: ctrl.updateBaseColor,
            ),
            _sectionDivider(),
            _categoryLabel('Layer Opacities'),
            _OpacitySettingsSection(draft: d, controller: ctrl),
          ],
        );
      case 2:
        return _LayersManagerTab(controller: ctrl, draft: d);

      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _categoryLabel('NPC Wildlife'),
            AssetPickerSection(
              label: 'Bird Sprite',
              subtitle: 'spritesheet 7 frames',
              paths: ['none', ...ctrl.birdPaths],
              selectedPath: d.birdPath,
              onSelected: ctrl.updateBird,
            ),
            if (d.birdPath != 'none' && d.birdPath.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _ScaleSliderRow(
                  label: 'Bird Size Scale',
                  value: d.birdScale,
                  onChanged: ctrl.updateBirdScale,
                ),
              ),
            AssetPickerSection(
              label: 'Rabbit Idle',
              subtitle: 'spritesheet 12 frames',
              paths: ['none', ...ctrl.rabbitIdlePaths],
              selectedPath: d.rabbitIdlePath,
              onSelected: ctrl.updateRabbitIdle,
            ),
            AssetPickerSection(
              label: 'Rabbit Run',
              subtitle: 'spritesheet 8 frames',
              paths: ['none', ...ctrl.rabbitRunPaths],
              selectedPath: d.rabbitRunPath,
              onSelected: ctrl.updateRabbitRun,
            ),
            if (d.rabbitIdlePath != 'none' && d.rabbitIdlePath.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _ScaleSliderRow(
                  label: 'Rabbit Size Scale',
                  value: d.rabbitScale,
                  onChanged: ctrl.updateRabbitScale,
                ),
              ),
            _sectionDivider(),
            _categoryLabel('Throwable Toys'),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _CustomSegmentedControl(
                options: const {
                  'tennis_ball': 'Tennis Ball',
                  'base_ball': 'Baseball',
                  'basket_ball': 'Basketball',
                  'football': 'Football',
                },
                selectedValue: _selectedToyKey,
                onSelected: (val) => setState(() => _selectedToyKey = val),
              ),
            ),
            AssetPickerSection(
              label: 'Configure ${_getToyLabel(_selectedToyKey)}',
              paths: ['none', ...ctrl.toyPaths],
              selectedPath:
                  d.toyPaths[_selectedToyKey] ??
                  (EnvironmentAssetCatalogue.toys[_selectedToyKey]?.path ??
                      'none'),
              onSelected: (p) => ctrl.updateToy(_selectedToyKey, p),
            ),
            _sectionDivider(),
            _categoryLabel('Food Items'),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _CustomSegmentedControl(
                options: const {'carrot': 'Carrot / Snack', 'bone': 'Bone'},
                selectedValue: _selectedFoodKey,
                onSelected: (val) => setState(() => _selectedFoodKey = val),
              ),
            ),
            AssetPickerSection(
              label: 'Configure ${_getFoodLabel(_selectedFoodKey)}',
              paths: ['none', ...ctrl.foodPaths],
              selectedPath:
                  d.foodPaths[_selectedFoodKey] ??
                  (EnvironmentAssetCatalogue.foods[_selectedFoodKey]?.path ??
                      'none'),
              onSelected: (p) => ctrl.updateFood(_selectedFoodKey, p),
            ),
          ],
        );
      case 4:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_SavedThemesSection(ctrl: ctrl)],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _categoryLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
          letterSpacing: -0.2,
          fontFamily: 'Inter',
        ),
      ),
    );
  }

  Widget _sectionDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Divider(height: 0.5, thickness: 0.5, color: AppTheme.border),
    );
  }
}

class _CustomSegmentedControl extends StatelessWidget {
  final Map<String, String> options;
  final String selectedValue;
  final ValueChanged<String> onSelected;

  const _CustomSegmentedControl({
    required this.options,
    required this.selectedValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.entries.map((entry) {
          final isSelected = entry.key == selectedValue;
          return GestureDetector(
            onTap: () => onSelected(entry.key),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.accent.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? AppTheme.accent : Colors.transparent,
                  width: 0.5,
                ),
              ),
              child: Text(
                entry.value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<EnvironmentBuilderController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: EnvPreviewPanel(theme: ctrl.draft),
          ),
        ),
        const Divider(height: 0.5, thickness: 0.5, color: AppTheme.border),
        _ActionBar(ctrl: ctrl),
      ],
    );
  }
}

class _ActionBar extends StatelessWidget {
  final EnvironmentBuilderController ctrl;

  const _ActionBar({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CupertinoTextField(
            placeholder: ctrl.draft.name,
            onSubmitted: ctrl.updateName,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontFamily: 'Inter',
            ),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            prefix: const Padding(
              padding: EdgeInsets.only(left: 12),
              child: Icon(
                Icons.label_outline_rounded,
                size: 14,
                color: AppTheme.textMuted,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            placeholderStyle: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 13,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 14),
                  label: const Text('Reset'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: BorderSide(color: AppTheme.border),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                    ),
                  ),
                  onPressed: ctrl.resetDraft,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  icon: ctrl.isSaving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded, size: 14),
                  label: Text(ctrl.isSaving ? 'Saving…' : 'Save Theme'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    disabledBackgroundColor: AppTheme.accent.withValues(
                      alpha: 0.5,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter',
                    ),
                  ),
                  onPressed: ctrl.isSaving ? null : () => _save(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    await ctrl.saveCurrentDraft();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Theme saved',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500),
        ),
        backgroundColor: AppTheme.surfaceElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: AppTheme.border),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _SavedThemesSection extends StatelessWidget {
  final EnvironmentBuilderController ctrl;

  const _SavedThemesSection({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    if (ctrl.savedThemes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Saved Themes',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: -0.2,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 12),
        for (final theme in ctrl.savedThemes)
          _SavedThemeTile(
            theme: theme,
            onLoad: () => ctrl.loadForEditing(theme),
            onDelete: () => ctrl.deleteSavedTheme(theme.id),
          ),
      ],
    );
  }
}

class _SavedThemeTile extends StatelessWidget {
  final CustomEnvironmentTheme theme;
  final VoidCallback onLoad;
  final VoidCallback onDelete;

  const _SavedThemeTile({
    required this.theme,
    required this.onLoad,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 36,
              height: 36,
              child: Column(
                children: [
                  Expanded(child: Container(color: Color(theme.baseColorArgb))),
                  Expanded(
                    child: Container(color: Color(theme.groundTintArgb)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  theme.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    fontFamily: 'Inter',
                  ),
                ),
                Text(
                  theme.id,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textMuted,
                    fontFamily: 'Inter',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 16),
            color: AppTheme.textSecondary,
            tooltip: 'Load for editing',
            onPressed: onLoad,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 16),
            color: AppTheme.error,
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          side: BorderSide(color: AppTheme.border),
        ),
        title: const Text(
          'Delete Theme',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Delete "${theme.name}"? This cannot be undone.',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontFamily: 'Inter',
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _OpacitySettingsSection extends StatelessWidget {
  final CustomEnvironmentTheme draft;
  final EnvironmentBuilderController controller;

  const _OpacitySettingsSection({
    required this.draft,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OpacitySliderRow(
          label: 'Sky/Background',
          value: draft.skyOpacity,
          onChanged: controller.updateSkyOpacity,
        ),
        _OpacitySliderRow(
          label: 'Cloud Sprite',
          value: draft.cloudOpacity,
          onChanged: controller.updateCloudOpacity,
        ),
        _OpacitySliderRow(
          label: 'Ground Tile',
          value: draft.groundOpacity,
          onChanged: controller.updateGroundOpacity,
        ),
        _OpacitySliderRow(
          label: 'Mountain Left/Right',
          value: draft.mountainOpacity,
          onChanged: controller.updateMountainOpacity,
        ),
        _OpacitySliderRow(
          label: 'Rock Left/Right',
          value: draft.rockOpacity,
          onChanged: controller.updateRockOpacity,
        ),
      ],
    );
  }
}

class _OpacitySliderRow extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _OpacitySliderRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              Text(
                '${(value * 100).round()}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accent,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              trackHeight: 3,
              activeTrackColor: AppTheme.accent,
              inactiveTrackColor: AppTheme.border,
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: value,
              min: 0.0,
              max: 1.0,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScaleSliderRow extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _ScaleSliderRow({
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              Text(
                '${value.toStringAsFixed(2)}x',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accent,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              trackHeight: 3,
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
        ],
      ),
    );
  }
}

class _LayersManagerTab extends StatefulWidget {
  final EnvironmentBuilderController controller;
  final CustomEnvironmentTheme draft;

  const _LayersManagerTab({required this.controller, required this.draft});

  @override
  State<_LayersManagerTab> createState() => _LayersManagerTabState();
}

class _LayersManagerTabState extends State<_LayersManagerTab> {
  String? _expandedLayerId;

  String _getFriendlyName(String path) {
    final name = path.split('/').last.replaceAll('.png', '');
    return name
        .split(RegExp(r'[-_]'))
        .map(
          (s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '',
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final List<CustomEnvironmentLayer> layers = widget.draft.layers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Scenery Layers',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                fontFamily: 'Inter',
              ),
            ),
            ElevatedButton.icon(
              onPressed: _showAddLayerDialog,
              icon: const Icon(CupertinoIcons.add, size: 14),
              label: const Text('Add Layer', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (layers.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.border, width: 0.5),
            ),
            child: const Column(
              children: [
                Icon(
                  CupertinoIcons.layers,
                  size: 32,
                  color: AppTheme.textMuted,
                ),
                SizedBox(height: 8),
                Text(
                  'No scenery layers yet.\nClick "Add Layer" to begin composing!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: layers.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final layer = layers[idx];
              final isExpanded = _expandedLayerId == layer.id;
              final displayName = _getFriendlyName(layer.assetPath);

              return Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: isExpanded ? AppTheme.accent : AppTheme.border,
                    width: isExpanded ? 1.0 : 0.5,
                  ),
                ),
                child: Column(
                  children: [
                    ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      leading: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSm,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSm,
                          ),
                          child: Image.asset(
                            layer.assetPath,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  CupertinoIcons.photo,
                                  size: 14,
                                  color: AppTheme.textMuted,
                                ),
                          ),
                        ),
                      ),
                      title: Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                          fontFamily: 'Inter',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'Layer ${idx + 1} (Priority: ${-8 + idx})',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.textMuted,
                          fontFamily: 'Inter',
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(CupertinoIcons.up_arrow, size: 14),
                            tooltip: 'Send Backward (Draw Earlier)',
                            onPressed: idx > 0
                                ? () => widget.controller.reorderLayers(
                                    idx,
                                    idx - 1,
                                  )
                                : null,
                          ),
                          IconButton(
                            icon: const Icon(
                              CupertinoIcons.down_arrow,
                              size: 14,
                            ),
                            tooltip: 'Bring Forward (Draw Later)',
                            onPressed: idx < layers.length - 1
                                ? () => widget.controller.reorderLayers(
                                    idx,
                                    idx + 2,
                                  )
                                : null,
                          ),
                          IconButton(
                            icon: Icon(
                              isExpanded
                                  ? CupertinoIcons.chevron_up
                                  : CupertinoIcons.chevron_down,
                              size: 14,
                            ),
                            onPressed: () {
                              setState(() {
                                _expandedLayerId = isExpanded ? null : layer.id;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    if (isExpanded) ...[
                      const Divider(height: 1, color: AppTheme.border),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildSliderRow(
                              label: 'Horizontal Pos (X)',
                              value: layer.xRatio,
                              min: -0.2,
                              max: 1.2,
                              displayValue: layer.xRatio.toStringAsFixed(2),
                              onChanged: (val) {
                                widget.controller.updateLayer(
                                  layer.copyWith(xRatio: val),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            _buildSliderRow(
                              label: 'Vertical Height (Y)',
                              value: layer.yRatio,
                              min: -0.2,
                              max: 1.2,
                              displayValue: layer.yRatio.toStringAsFixed(2),
                              onChanged: (val) {
                                widget.controller.updateLayer(
                                  layer.copyWith(yRatio: val),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            _buildSliderRow(
                              label: 'Scale Size',
                              value: layer.scale,
                              min: 0.1,
                              max: 3.0,
                              displayValue: layer.scale.toStringAsFixed(2),
                              onChanged: (val) {
                                widget.controller.updateLayer(
                                  layer.copyWith(scale: val),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            _buildSliderRow(
                              label: 'Opacity',
                              value: layer.opacity,
                              min: 0.0,
                              max: 1.0,
                              displayValue: layer.opacity.toStringAsFixed(2),
                              onChanged: (val) {
                                widget.controller.updateLayer(
                                  layer.copyWith(opacity: val),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Flip Horizontally',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textPrimary,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    CupertinoSwitch(
                                      value: layer.flipX,
                                      activeTrackColor: AppTheme.accent,
                                      onChanged: (val) {
                                        widget.controller.updateLayer(
                                          layer.copyWith(flipX: val),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    TextButton.icon(
                                      onPressed: () {
                                        widget.controller.duplicateLayer(layer);
                                      },
                                      icon: const Icon(
                                        CupertinoIcons.doc_on_doc,
                                        size: 12,
                                      ),
                                      label: const Text(
                                        'Duplicate',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppTheme.textSecondary,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    TextButton.icon(
                                      onPressed: () {
                                        widget.controller.removeLayer(layer.id);
                                        if (_expandedLayerId == layer.id) {
                                          _expandedLayerId = null;
                                        }
                                      },
                                      icon: const Icon(
                                        CupertinoIcons.trash,
                                        size: 12,
                                      ),
                                      label: const Text(
                                        'Delete',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.redAccent,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required String displayValue,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              fontFamily: 'Inter',
            ),
          ),
        ),
        Expanded(
          flex: 5,
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
        SizedBox(
          width: 36,
          child: Text(
            displayValue,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
              fontFamily: 'SFMono-Regular, Consolas, Courier, monospace',
            ),
          ),
        ),
      ],
    );
  }

  void _showAddLayerDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return _AddLayerDialog(controller: widget.controller);
      },
    );
  }
}

class _AddLayerDialog extends StatefulWidget {
  final EnvironmentBuilderController controller;

  const _AddLayerDialog({required this.controller});

  @override
  State<_AddLayerDialog> createState() => _AddLayerDialogState();
}

class _AddLayerDialogState extends State<_AddLayerDialog> {
  int _activeDialogTab = 0;

  String _getFriendlyName(String path) {
    final name = path.split('/').last.replaceAll('.png', '');
    return name
        .split(RegExp(r'[-_]'))
        .map(
          (s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '',
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final List<String> paths;
    if (_activeDialogTab == 0) {
      paths = widget.controller.mountainPaths;
    } else if (_activeDialogTab == 1) {
      paths = widget.controller.rockPaths;
    } else {
      paths = widget.controller.cloudPaths;
    }

    return Dialog(
      backgroundColor: AppTheme.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Container(
        width: 450,
        height: 400,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add Scenery Layer',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    fontFamily: 'Inter',
                  ),
                ),
                IconButton(
                  icon: const Icon(CupertinoIcons.xmark, size: 16),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _dialogTabButton(0, 'Mountains & Trees'),
                const SizedBox(width: 8),
                _dialogTabButton(1, 'Rocks & Stones'),
                const SizedBox(width: 8),
                _dialogTabButton(2, 'Clouds'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.85,
                ),
                itemCount: paths.length,
                itemBuilder: (context, idx) {
                  final path = paths[idx];
                  final name = _getFriendlyName(path);
                  return GestureDetector(
                    onTap: () {
                      widget.controller.addLayer(path);
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceCard.withValues(alpha: 0.5),
                        border: Border.all(color: AppTheme.border, width: 0.5),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        children: [
                          Expanded(
                            child: Image.asset(
                              path,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                    CupertinoIcons.photo,
                                    size: 24,
                                    color: AppTheme.textMuted,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.textSecondary,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogTabButton(int idx, String label) {
    final isSelected = _activeDialogTab == idx;
    return GestureDetector(
      onTap: () => setState(() => _activeDialogTab = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: isSelected ? Colors.transparent : AppTheme.border,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontFamily: 'Inter',
          ),
        ),
      ),
    );
  }
}
