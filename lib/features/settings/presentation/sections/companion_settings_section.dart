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
                  max: 8.0,
                ),
              ]),

              if (widget.controller.pipModeEnabled) ...[
                sectionHeader('Draggable PiP Panel Settings'),
                buildCard([
                  dropdownRow(
                    'Background Style',
                    widget.controller.pipBackgroundStyle,
                    const ['dark', 'light', 'transparent'],
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
                      'toy_mouse',
                      'pink_yarn',
                      'orange_yarn',
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
        Container(
          width: double.infinity,
          height: 280, // Taller header
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: AppTheme.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    panEnabled: true,
                    scaleEnabled: false,
                    constrained:
                        false, // Allow child to be wider than container
                    boundaryMargin: const EdgeInsets.symmetric(
                      horizontal: 1000,
                    ),
                    child: CompanionSpriteWidget(
                      petTheme: currentTheme,
                      animationState: PetAnimationState.idle,
                      scale: 6.0, // Large prominent pet
                      backgroundImagePath:
                          widget.controller.companionPreviewBackground,
                      isStatic: false,
                      size: const Size(2000, 280), // Panoramic width
                      petYOffset: 0.0, // Grounded by Alignment.bottomCenter
                    ),
                  ),
                ),

                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.5, 1.0],
                        colors: [
                          Colors.black.withValues(alpha: 0.0),
                          Colors.black.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                  ),
                ),

                Positioned(
                  left: 28,
                  bottom: 28,
                  right: 28,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.accentColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                currentTheme.species.name.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              widget.controller.companionEnabled
                                  ? widget.controller.companionPetName
                                  : 'Companion',
                              style: const TextStyle(
                                fontSize: 36, // Large bold name
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildSyncCard(), // Unified Sync Button
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildBackgroundPicker(),
      ],
    );
  }

  Widget _buildBackgroundPicker() {
    final backgrounds = [
      {'name': 'Forest', 'path': 'assets/background/forest/background.png'},
      {'name': 'Autumn', 'path': 'assets/background/autumn/background.png'},
      {'name': 'Winter', 'path': 'assets/background/winter/background.png'},
      {'name': 'Beach', 'path': 'assets/background/beach/background-light.png'},
      {'name': 'Cave', 'path': 'assets/background/cave/background.png'},
      {'name': 'Desert', 'path': 'assets/background/desert/background.png'},
      {'name': 'Sky', 'path': 'assets/background/sky/background.png'},
      {
        'name': 'Night Town',
        'path': 'assets/background/night_town/background.png',
      },
      {
        'name': 'Mist Forest',
        'path': 'assets/background/mist_forest/background.png',
      },
      {'name': 'Urban', 'path': 'assets/background/urban/background.png'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PREVIEW ENVIRONMENT',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: AppTheme.textSecondary,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: backgrounds.map((bg) {
              final isSelected =
                  widget.controller.companionPreviewBackground == bg['path'];
              return GestureDetector(
                onTap: () =>
                    widget.controller.changePreviewBackground(bg['path']!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.accentColor
                        : AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.accentColor
                          : AppTheme.border,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.accentColor.withValues(
                                alpha: 0.25,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: Text(
                    bg['name']!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: isSelected ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
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
