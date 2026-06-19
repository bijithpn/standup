import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:breakmate/features/companion/domain/custom_environment_theme.dart';
import 'package:breakmate/shared/shared.dart';
import '../environment_builder_controller.dart';
import 'asset_picker_section.dart';
import 'colors_section_tab.dart';
import 'custom_segmented_control.dart';
import 'layers_manager_tab.dart';
import 'saved_themes_section.dart';
import 'opacity_settings_section.dart';

class PickerPanel extends StatefulWidget {
  const PickerPanel({super.key});

  @override
  State<PickerPanel> createState() => _PickerPanelState();
}

class _TabItem {
  final IconData icon;
  final String label;
  const _TabItem(this.icon, this.label);
}

class _PickerPanelState extends State<PickerPanel> {
  int _activeTab = 0;
  String _selectedToyKey = 'tennis_ball';
  String _selectedFoodKey = 'carrot';

  static const List<_TabItem> _tabs = [
    _TabItem(CupertinoIcons.photo, 'Canvas'),
    _TabItem(CupertinoIcons.color_filter, 'Colors'),
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
                    color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tab.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
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
                  const Expanded(
                    child: Column(
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
                  ),
                  const SizedBox(width: 8),
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
        return ColorsSectionTab(controller: ctrl, draft: d);
      case 2:
        return LayersManagerTab(controller: ctrl, draft: d);
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
                child: ScaleSliderRow(
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
                child: ScaleSliderRow(
                  label: 'Rabbit Size Scale',
                  value: d.rabbitScale,
                  onChanged: ctrl.updateRabbitScale,
                ),
              ),
            _sectionDivider(),
            _categoryLabel('Throwable Toys'),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: CustomSegmentedControl(
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
              selectedPath: d.toyPaths[_selectedToyKey] ??
                  (EnvironmentAssetCatalogue.toys[_selectedToyKey]?.path ?? 'none'),
              onSelected: (p) => ctrl.updateToy(_selectedToyKey, p),
            ),
            _sectionDivider(),
            _categoryLabel('Food Items'),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: CustomSegmentedControl(
                options: const {'carrot': 'Carrot / Snack', 'bone': 'Bone'},
                selectedValue: _selectedFoodKey,
                onSelected: (val) => setState(() => _selectedFoodKey = val),
              ),
            ),
            AssetPickerSection(
              label: 'Configure ${_getFoodLabel(_selectedFoodKey)}',
              paths: ['none', ...ctrl.foodPaths],
              selectedPath: d.foodPaths[_selectedFoodKey] ??
                  (EnvironmentAssetCatalogue.foods[_selectedFoodKey]?.path ?? 'none'),
              onSelected: (p) => ctrl.updateFood(_selectedFoodKey, p),
            ),
          ],
        );
      case 4:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SavedThemesSection(
              ctrl: ctrl,
              onLoaded: () {
                setState(() => _activeTab = 0);
              },
            ),
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
