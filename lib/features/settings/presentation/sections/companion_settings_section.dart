import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:breakmate/features/companion/controllers/companion_overlay_controller.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/core/native/native_bridge.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/features/companion/presentation/customizer/avatar_customizer_page.dart';
import 'package:breakmate/features/companion/presentation/widgets/avatar_view.dart';
import 'package:breakmate/features/companion/services/companion_streak_service.dart';
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
        final isTransitioning = widget.controller.isTransitioning;
        return Stack(
          children: [
            Column(
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
                        Icon(
                          CupertinoIcons.info_circle,
                          size: 18,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.controller.companionStateExplanation,
                            style: TextStyle(
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

                  sectionHeader('Streak Recognition'),
                  _buildStreakCard(),
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
                    '3D Pet Customizer',
                    subtitle: 'Choose from 30+ species, custom seeds, and OneWorks palettes',
                  ),
                  buildCard([
                    buildListRow(
                      'Open 3D Pet Customizer',
                      'Customize procedural 3D avatar with 30+ species, colors, seeds and animations.',
                      null,
                      Icons.pets_rounded,
                      null,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AvatarCustomizerPage(),
                          fullscreenDialog: true,
                        ),
                      ),
                      trailing: Icon(
                        CupertinoIcons.chevron_right,
                        size: 14,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ]),


                ],
                const SizedBox(height: 40),
              ],
            ),
            if (isTransitioning)
              Positioned.fill(
                child: AbsorbPointer(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.15),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceElevated.withValues(
                            alpha: 0.9,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CupertinoActivityIndicator(
                              color: AppTheme.accentColor,
                              radius: 10,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Configuring Companion...',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
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
                        style: TextStyle(
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
                  Text(
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
      ],
    );
  }

  Widget _buildStreakCard() {
    return AnimatedBuilder(
      animation: sl<CompanionStreakService>(),
      builder: (context, _) {
        final streakService = sl<CompanionStreakService>();
        final current = streakService.currentStreakDays;
        final highest = streakService.highestMilestone;
        final next = streakService.nextMilestone;
        final daysToNext = next != null ? next.days - current : null;

        return buildCard([
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.flame_fill,
                  size: 18,
                  color: current > 0 ? AppTheme.accent : AppTheme.textMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        current > 0
                            ? '$current-day streak'
                                '${highest != null ? ' · ${highest.label}' : ''}'
                            : 'No active streak yet',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (next != null && daysToNext != null && daysToNext > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          '$daysToNext day${daysToNext == 1 ? '' : 's'} to '
                          '"${next.label}"',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ]);
      },
    );
  }

  Widget _buildPetGallery() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            sectionHeader(
              '3D Pet Gallery',
              subtitle: 'Select from 30+ OneWorks 3D species',
            ),
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AvatarCustomizerPage(),
                  fullscreenDialog: true,
                ),
              ),
              icon: const Icon(Icons.palette_outlined, size: 16),
              label: const Text('Customize 3D'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.accentColor,
                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.9,
          ),
          itemCount: PetTheme.themes.length,
          itemBuilder: (context, index) {
            final theme = PetTheme.themes[index];
            final isSelected = widget.controller.companionPetTheme == theme.id;
            final isLocked = theme.requiredConsistencyDays > 0 &&
                (sl<CompanionStreakService>().currentStreakDays <
                    theme.requiredConsistencyDays);

            return GestureDetector(
              onTap: isLocked
                  ? () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Requires a ${theme.requiredConsistencyDays}-day streak to unlock!',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  : () => widget.controller.changeTheme(theme.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.accentColor.withValues(alpha: 0.15)
                      : AppTheme.surfaceElevated.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AppTheme.accentColor : AppTheme.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Center(
                        child: theme.avatarDefinition != null
                            ? AvatarView(
                                definition: theme.avatarDefinition!,
                                isInteractive: false,
                                autoTrackCursor: false,
                                width: 56,
                                height: 56,
                              )
                            : Icon(
                                Icons.pets_rounded,
                                size: 36,
                                color: isSelected
                                    ? AppTheme.accentColor
                                    : AppTheme.textMuted,
                              ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      theme.name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? AppTheme.accentColor
                            : AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    if (isLocked)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.lock_fill,
                              size: 10,
                              color: AppTheme.textMuted,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${theme.requiredConsistencyDays}d',
                              style: TextStyle(
                                fontSize: 9,
                                color: AppTheme.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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
                    style: TextStyle(
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
