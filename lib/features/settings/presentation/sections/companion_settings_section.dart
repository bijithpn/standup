import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:breakmate/features/companion/controllers/companion_overlay_controller.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/core/native/native_bridge.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/companion_sprite_widget.dart';
import 'package:breakmate/features/companion/domain/pet_animation_state.dart';
import 'package:breakmate/shared/widgets/app_dropdown.dart';
import 'package:breakmate/features/companion/presentation/environment_builder/environment_builder_page.dart';
import 'package:breakmate/features/companion/services/custom_environment_repository.dart';
import 'package:breakmate/app/dependency_injection.dart';

class CompanionSettingsSection extends StatefulWidget {
  final CompanionOverlayController controller;

  const CompanionSettingsSection({super.key, required this.controller});

  @override
  State<CompanionSettingsSection> createState() =>
      _CompanionSettingsSectionState();
}

class _CompanionSettingsSectionState extends State<CompanionSettingsSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.controller.setPreviewMode(true);
      }
    });
  }

  @override
  void dispose() {
    widget.controller.setPreviewMode(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroHeader(),
            const SizedBox(height: 32),

            sectionHeader('Status'),
            buildCard([
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.info_circle,
                      size: 18,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.controller.companionStateExplanation,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              divider(),
              toggleRow(
                'Show Companion',
                'Enable your desktop pet to see it wandering around your screen.',
                widget.controller.companionEnabled,
                (v) => widget.controller.toggleCompanion(v),
              ),
              if (Platform.isMacOS || Platform.isWindows) ...[
                divider(),
                toggleRow(
                  'Draggable PiP Panel',
                  'Run the companion in a compact, floating always-on-top window rather than a full-screen transparent overlay.',
                  widget.controller.pipModeEnabled,
                  (v) => widget.controller.changePipModeEnabled(v),
                ),
              ],
            ]),

            if (widget.controller.companionEnabled) ...[
              _buildPetGallery(),
              const SizedBox(height: 32),

              sectionHeader('Personalization'),
              buildCard([
                textFieldRow(
                  'Companion Name',
                  widget.controller.companionPetName,
                  (v) => widget.controller.changePetName(v),
                ),
                divider(),
                sliderRow(
                  'Visual Scale (${widget.controller.companionScale.toStringAsFixed(1)}x)',
                  widget.controller.companionScale,
                  (v) {
                    final snapped = (v * 2.0).roundToDouble() / 2.0;
                    widget.controller.changeScale(snapped);
                  },
                  min: 2.0,
                  max: 15.0,
                ),
              ]),

              if (widget.controller.pipModeEnabled) ...[
                sectionHeader('Draggable PiP Panel Settings'),
                buildCard([
                  dropdownRow(
                    'Background Style',
                    widget.controller.pipBackgroundStyle,
                    const ['dark', 'light'],
                    (v) {
                      if (v != null) {
                        widget.controller.changePipBackgroundStyle(v);
                      }
                    },
                  ),
                  divider(),
                  sliderRow(
                    'Window Opacity (${(widget.controller.pipOpacity * 100).round()}%)${widget.controller.pipOpacity == 1.0 ? " (Opaque)" : ""}',
                    widget.controller.pipOpacity,
                    (v) => widget.controller.changePipOpacity(v),
                    min: 0.1,
                    max: 1.0,
                  ),
                  divider(),
                  toggleRow(
                    'Draggable Area Clickable',
                    'Enables click/drag on the handle. If disabled, the entire window ignores mouse clicks (click-through).',
                    widget.controller.pipDraggableClickable,
                    (v) => widget.controller.changePipDraggableClickable(v),
                  ),
                ]),
              ],

              sectionHeader('Behavior'),
              buildCard([
                toggleRow(
                  'Low-distraction Focus Mode',
                  'Reduces motion, disables cursor chasing, and makes the companion click-through.',
                  widget.controller.isLowDistractionMode,
                  (v) => widget.controller.setLowDistractionMode(v),
                ),
                divider(),
                toggleRow(
                  'Ghost Mode (Click-through)',
                  'Let the pet stay visible but ignore all mouse interactions.',
                  widget.controller.companionClickThrough,
                  (v) => widget.controller.changeClickThrough(v),
                ),
                divider(),
                toggleRow(
                  'Magnetic Attraction',
                  'The pet will dynamically move toward and follow your cursor.',
                  widget.controller.companionFollowMouse,
                  (v) => widget.controller.changeFollowMouse(v),
                ),
              ]),

              const SizedBox(height: 32),

              sectionHeader('Interaction Features'),
              buildCard([
                toggleRow(
                  'Petting & Affection',
                  'Interact with your pet by hovering or moving your cursor over it.',
                  widget.controller.pettingEnabled,
                  (v) => widget.controller.changePettingEnabled(v),
                ),
                divider(),
                toggleRow(
                  'Play Fetch',
                  'Allow throwing balls from the action bar for the pet to chase.',
                  widget.controller.ballThrowEnabled,
                  (v) => widget.controller.changeBallThrowEnabled(v),
                ),
                if (widget.controller.ballThrowEnabled) ...[
                  divider(),
                  dropdownRow(
                    'Throwable Toy Type',
                    widget.controller.companionToyType,
                    const [
                      'tennis_ball',
                      'base_ball',
                      'basket_ball',
                      'football',
                    ],
                    (v) {
                      if (v != null) {
                        widget.controller.changeToyType(v);
                      }
                    },
                  ),
                ],
                divider(),
                toggleRow(
                  'Feed Treats',
                  'Allow feeding treats to your pet from the action bar.',
                  widget.controller.treatEnabled,
                  (v) => widget.controller.changeTreatEnabled(v),
                ),
                if (widget.controller.treatEnabled) ...[
                  divider(),
                  dropdownRow(
                    'Feed Treat Type',
                    widget.controller.companionTreatType,
                    const ['sushi', 'bone', 'carrot'],
                    (v) {
                      if (v != null) {
                        widget.controller.changeTreatType(v);
                      }
                    },
                  ),
                ],
                divider(),
                toggleRow(
                  'Developer Milestones',
                  'Enable pet reactions triggered by coding accomplishments.',
                  widget.controller.developerReactions,
                  (v) => widget.controller.changeDeveloperReactions(v),
                ),
                divider(),
                toggleRow(
                  'Quiet Mode Auto-Activation',
                  'Automatically calm the pet during meetings, focus blocks, or battery-saver mode.',
                  widget.controller.quietModeAutoActivate,
                  (v) => widget.controller.changeQuietModeAutoActivate(v),
                ),
              ]),

              const SizedBox(height: 32),
              sectionHeader('Animation Lab'),
              _buildInteractionGrid(),

              const SizedBox(height: 32),
              sectionHeader(
                'Environment Builder',
                subtitle: 'Design custom world themes with your own assets',
              ),
              buildCard([
                buildListRow(
                  'Open Environment Builder',
                  'Pick sky, ground, rocks, birds, rabbits and colour tints to craft a custom world.',
                  null,
                  Icons.landscape_rounded,
                  null,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EnvironmentBuilderPage(),
                      fullscreenDialog: true,
                    ),
                  ),
                  trailing: const Icon(
                    CupertinoIcons.chevron_right,
                    size: 14,
                    color: AppTheme.textMuted,
                  ),
                ),
              ]),
            ],
            const SizedBox(height: 40),
          ],
        );
      },
    );
  }

  Widget _buildHeroHeader() {
    final currentTheme = PetTheme.getTheme(widget.controller.companionPetTheme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.controller.companionEnabled
                            ? widget.controller.companionPetName
                            : 'Companion',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.accentColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          currentTheme.species.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.accentColor,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Customize and preview your companion settings.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            _buildSyncCard(),
          ],
        ),
        const SizedBox(height: 24),
        _buildBackgroundPicker(),
      ],
    );
  }

  Widget _buildBackgroundPicker() {
    final backgrounds = [
      {
        'name': 'Forest',
        'id': 'forest',
        'path': 'assets/background/forest/background.png'
      },
      {
        'name': 'Autumn',
        'id': 'autumn',
        'path': 'assets/background/autumn/background.png'
      },
      {
        'name': 'Winter',
        'id': 'winter',
        'path': 'assets/background/winter/background.png'
      },
      {
        'name': 'Beach',
        'id': 'beach',
        'path': 'assets/background/beach/background-light.png'
      },
      {
        'name': 'Desert',
        'id': 'desert',
        'path': 'assets/background/desert/background.png'
      },
      {
        'name': 'Sky',
        'id': 'sky',
        'path': 'assets/environments/sky/sky_back.png'
      },
      {
        'name': 'Night Town',
        'id': 'night_town',
        'path': 'assets/environments/background/bg_night_town.png',
      },
      {
        'name': 'Mist Forest',
        'id': 'mist_forest',
        'path': 'assets/environments/background/bg_mist_forest.png',
      },
      {
        'name': 'Urban',
        'id': 'urban',
        'path': 'assets/background/urban/background.png'
      },
    ];

    try {
      final repo = sl<CustomEnvironmentRepository>();
      final customThemes = repo.themes.isEmpty ? repo.loadSync() : repo.themes;
      for (final theme in customThemes) {
        if (!backgrounds.any((bg) => bg['id'] == theme.id)) {
          backgrounds.add({
            'name': theme.name,
            'id': theme.id,
            'path': theme.skyPath,
          });
        }
      }
    } catch (_) {}

    final currentBg = widget.controller.companionPreviewBackground;
    final selectedBg = backgrounds.firstWhere(
      (bg) => bg['id'] == currentBg,
      orElse: () {
        // Fallback to match by skyPath (for backward compatibility)
        return backgrounds.firstWhere(
          (bg) => bg['path'] == currentBg,
          orElse: () => backgrounds.first,
        );
      },
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Preview Environment',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Used to preview sprites below',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
          AppDropdown<String>(
            value: selectedBg['id']!,
            width: 180,
            onChanged: (id) {
              if (id != null) {
                widget.controller.changePreviewBackground(id);
              }
            },
            items: backgrounds.map((bg) {
              final isThisSelected = bg['id'] == selectedBg['id'];
              return AppDropdownItem<String>(
                value: bg['id']!,
                label: bg['name']!,
                customChild: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.asset(
                        bg['path']!,
                        width: 28,
                        height: 18,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      bg['name']!,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5,
                        fontWeight: isThisSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isThisSelected
                            ? AppTheme.accentColor
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPetGallery() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        sectionHeader(
          'Pet Gallery',
          subtitle: 'Select a variant to change your companion instantly',
        ),

        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.0,
          ),
          itemCount: PetTheme.themes.length,
          itemBuilder: (context, index) {
            final theme = PetTheme.themes[index];
            final isSelected = widget.controller.companionPetTheme == theme.id;

            return GestureDetector(
              onTap: () => widget.controller.changeTheme(theme.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutExpo,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.accentColor.withValues(alpha: 0.15)
                      : AppTheme.surfaceElevated.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AppTheme.accentColor : AppTheme.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CompanionSpriteWidget(
                        petTheme: theme,
                        animationState: isSelected
                            ? PetAnimationState.excited
                            : PetAnimationState.idle,
                        scale: 2.5, // Significantly larger to fill space
                        isStatic: true,
                        size: Size.infinite,
                        backgroundImagePath:
                            widget.controller.companionPreviewBackground,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSyncCard() {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: AppTheme.accentColor,
      borderRadius: BorderRadius.circular(12),
      onPressed: () => widget.controller.refreshCompanion(),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.arrow_2_circlepath,
            color: Colors.white,
            size: 18,
          ),
          SizedBox(width: 8),
          Text(
            'Sync Companion',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionGrid() {
    final List<Map<String, dynamic>> interactions;

    interactions = [
      {'label': 'Walk', 'icon': CupertinoIcons.paw, 'state': 'walk'},
      {'label': 'Nap', 'icon': CupertinoIcons.moon_zzz_fill, 'state': 'sleep'},
      {
        'label': 'Stretch',
        'icon': CupertinoIcons.sparkles,
        'state': 'celebrate',
      },
      {'label': 'Angry', 'icon': CupertinoIcons.flame_fill, 'state': 'angry'},
      {
        'label': 'Alert',
        'icon': CupertinoIcons.bell_fill,
        'state': 'notification',
      },
      {'label': 'Lick', 'icon': CupertinoIcons.heart_fill, 'state': 'lick1'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemCount: interactions.length,
      itemBuilder: (context, index) {
        final inter = interactions[index];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () =>
                NativeBridge.triggerCompanionState(inter['state'] as String),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    inter['icon'] as IconData,
                    size: 16,
                    color: AppTheme.accentColor,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    inter['label'] as String,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
