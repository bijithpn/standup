import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/companion/domain/custom_environment_theme.dart';
import 'package:breakmate/features/companion/services/custom_environment_repository.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'environment_builder_controller.dart';
import 'widgets/env_preview_panel.dart';
import 'widgets/asset_picker_section.dart';
import 'widgets/color_picker_row.dart';
import 'widgets/code_output_sheet.dart';

// Full-screen Environment Builder screen. Provides the controller and splits
// into a left picker panel and a right sticky preview panel.
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
    return Scaffold(
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
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final controller = context.read<EnvironmentBuilderController>();
    return AppBar(
      backgroundColor: AppTheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leadingWidth: 110,
      leading: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            icon: const Icon(CupertinoIcons.chevron_left, size: 18),
            color: AppTheme.textSecondary,
            onPressed: () => Navigator.pop(context),
            tooltip: 'Back',
          ),
          const SizedBox(width: 8),
        ],
      ),
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
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Wide layout (≥800px): left picker panel + right sticky preview
// ──────────────────────────────────────────────────────────────────────────────

class _WideLayout extends StatelessWidget {
  const _WideLayout();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: scrollable asset pickers
        Expanded(
          flex: 55,
          child: _PickerPanel(),
        ),
        Container(width: 0.5, color: AppTheme.border),
        // Right: sticky preview + action bar
        Expanded(
          flex: 45,
          child: _PreviewPanel(),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Narrow layout (<800px): stacked, preview at top, pickers below
// ──────────────────────────────────────────────────────────────────────────────

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
              builder: (_, ctrl, _) =>
                  EnvPreviewPanel(theme: ctrl.draft),
            ),
          ),
        ),
        const Divider(height: 0.5, thickness: 0.5, color: AppTheme.border),
        Expanded(child: _PickerPanel()),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Picker panel — all asset category sections
// ──────────────────────────────────────────────────────────────────────────────

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

  static const List<_TabItem> _tabs = [
    _TabItem(CupertinoIcons.photo, 'Canvas'),
    _TabItem(CupertinoIcons.color_filter, 'Tints & Blend'),
    _TabItem(CupertinoIcons.tree, 'Decorations'),
    _TabItem(CupertinoIcons.paw, 'NPCs & Wildlife'),
    _TabItem(CupertinoIcons.bookmark, 'Saved Themes'),
  ];

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<EnvironmentBuilderController>();
    final d = ctrl.draft;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTabs(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: _buildContent(ctrl, d),
          ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: AppTheme.surfaceCard,
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 0.5)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: List.generate(_tabs.length, (idx) {
            final tab = _tabs[idx];
            final isSelected = _activeTab == idx;
            return GestureDetector(
              onTap: () => setState(() => _activeTab = idx),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? AppTheme.accent : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      tab.icon,
                      size: 14,
                      color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildContent(EnvironmentBuilderController ctrl, CustomEnvironmentTheme d) {
    switch (_activeTab) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _categoryLabel('Background & Sky'),
            AssetPickerSection(
              label: 'Sky / Background',
              paths: EnvironmentAssetCatalogue.skyPaths,
              selectedPath: d.skyPath,
              onSelected: ctrl.updateSky,
            ),
            AssetPickerSection(
              label: 'Ground Tile',
              paths: EnvironmentAssetCatalogue.groundPaths,
              selectedPath: d.groundPath,
              onSelected: ctrl.updateGround,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 16, left: 4, right: 4),
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
              paths: const ['none', ...EnvironmentAssetCatalogue.cloudPaths],
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _categoryLabel('Landscape Decorations'),
            AssetPickerSection(
              label: 'Mountain Left',
              subtitle: 'background midground',
              paths: ['none', ...EnvironmentAssetCatalogue.mountains.map((c) => c.path)],
              selectedPath: d.mountainLeftPath,
              onSelected: ctrl.updateMountainLeft,
            ),
            AssetPickerSection(
              label: 'Mountain Right',
              subtitle: 'background midground',
              paths: ['none', ...EnvironmentAssetCatalogue.mountains.map((c) => c.path)],
              selectedPath: d.mountainRightPath,
              onSelected: ctrl.updateMountainRight,
            ),
            AssetPickerSection(
              label: 'Rock Left',
              subtitle: 'ground level',
              paths: ['none', ...EnvironmentAssetCatalogue.rocks.map((c) => c.path)],
              selectedPath: d.rockLeftPath,
              onSelected: ctrl.updateRockLeft,
            ),
            AssetPickerSection(
              label: 'Rock Right',
              subtitle: 'ground level',
              paths: ['none', ...EnvironmentAssetCatalogue.rocks.map((c) => c.path)],
              selectedPath: d.rockRightPath,
              onSelected: ctrl.updateRockRight,
            ),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _categoryLabel('NPC Wildlife'),
            AssetPickerSection(
              label: 'Bird Sprite',
              subtitle: 'spritesheet 7 frames',
              paths: ['none', ...EnvironmentAssetCatalogue.birds.map((c) => c.path)],
              selectedPath: d.birdPath,
              onSelected: ctrl.updateBird,
            ),
            AssetPickerSection(
              label: 'Rabbit Idle',
              subtitle: 'spritesheet 12 frames',
              paths: ['none', ...EnvironmentAssetCatalogue.rabbitIdle.map((c) => c.path)],
              selectedPath: d.rabbitIdlePath,
              onSelected: ctrl.updateRabbitIdle,
            ),
            AssetPickerSection(
              label: 'Rabbit Run',
              subtitle: 'spritesheet 8 frames',
              paths: ['none', ...EnvironmentAssetCatalogue.rabbitRun.map((c) => c.path)],
              selectedPath: d.rabbitRunPath,
              onSelected: ctrl.updateRabbitRun,
            ),
            _sectionDivider(),
            _categoryLabel('Throwable Toys'),
            AssetPickerSection(
              label: 'Tennis Ball',
              paths: ['none', ...EnvironmentAssetCatalogue.toys.values.map((c) => c.path)],
              selectedPath: d.toyPaths['tennis_ball'] ?? EnvironmentAssetCatalogue.toys['tennis_ball']!.path,
              onSelected: (p) => ctrl.updateToy('tennis_ball', p),
            ),
            AssetPickerSection(
              label: 'Baseball',
              paths: ['none', ...EnvironmentAssetCatalogue.toys.values.map((c) => c.path)],
              selectedPath: d.toyPaths['base_ball'] ?? EnvironmentAssetCatalogue.toys['base_ball']!.path,
              onSelected: (p) => ctrl.updateToy('base_ball', p),
            ),
            AssetPickerSection(
              label: 'Basketball',
              paths: ['none', ...EnvironmentAssetCatalogue.toys.values.map((c) => c.path)],
              selectedPath: d.toyPaths['basket_ball'] ?? EnvironmentAssetCatalogue.toys['basket_ball']!.path,
              onSelected: (p) => ctrl.updateToy('basket_ball', p),
            ),
            AssetPickerSection(
              label: 'Football',
              paths: ['none', ...EnvironmentAssetCatalogue.toys.values.map((c) => c.path)],
              selectedPath: d.toyPaths['football'] ?? EnvironmentAssetCatalogue.toys['football']!.path,
              onSelected: (p) => ctrl.updateToy('football', p),
            ),
            _sectionDivider(),
            _categoryLabel('Food Items'),
            AssetPickerSection(
              label: 'Carrot / Snack',
              paths: ['none', ...EnvironmentAssetCatalogue.foods.values.map((c) => c.path)],
              selectedPath: d.foodPaths['carrot'] ?? EnvironmentAssetCatalogue.foods['carrot']!.path,
              onSelected: (p) => ctrl.updateFood('carrot', p),
            ),
            AssetPickerSection(
              label: 'Bone',
              paths: ['none', ...EnvironmentAssetCatalogue.foods.values.map((c) => c.path)],
              selectedPath: d.foodPaths['bone'] ?? EnvironmentAssetCatalogue.foods['bone']!.path,
              onSelected: (p) => ctrl.updateFood('bone', p),
            ),
          ],
        );
      case 4:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SavedThemesSection(ctrl: ctrl),
          ],
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

// ──────────────────────────────────────────────────────────────────────────────
// Preview panel — sticky on the right on wide screens
// ──────────────────────────────────────────────────────────────────────────────

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
          // Theme name input
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
              child: Icon(Icons.label_outline_rounded,
                  size: 14, color: AppTheme.textMuted),
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
                    disabledBackgroundColor:
                        AppTheme.accent.withValues(alpha: 0.5),
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

// ──────────────────────────────────────────────────────────────────────────────
// Saved themes list at the bottom of the picker panel
// ──────────────────────────────────────────────────────────────────────────────

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
          // Colour swatch strip
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 36,
              height: 36,
              child: Column(
                children: [
                  Expanded(
                    child: Container(color: Color(theme.baseColorArgb)),
                  ),
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
