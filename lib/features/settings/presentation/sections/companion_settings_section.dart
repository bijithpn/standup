import 'package:breakmate/shared/widgets/minimal_controls.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:breakmate/core/config/flavor_config.dart';
import 'package:breakmate/features/companion/render/avatar_artwork.dart';
import 'package:breakmate/features/companion/render/avatar_artwork_recipe.dart';
import 'package:breakmate/features/companion/controllers/companion_overlay_controller.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_3d_view.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene_style.dart';
import 'package:breakmate/features/companion/domain/avatar_palette.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/presentation/widgets/companion_pet.dart';
import 'package:blobatar_flutter/blobatar_flutter.dart';
import 'package:breakmate/features/companion/presentation/widgets/blobatar_companion_widget.dart';
import 'package:breakmate/features/companion/presentation/widgets/blobatar_name_dialog.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/features/companion/services/companion_streak_service.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

/// Settings > Companion: pet gallery, size, name, gaze sensitivity and streak, all applied through [CompanionOverlayController].
class CompanionSettingsSection extends StatefulWidget {
  final CompanionOverlayController controller;

  const CompanionSettingsSection({super.key, required this.controller});

  @override
  State<CompanionSettingsSection> createState() =>
      _CompanionSettingsSectionState();
}

class _CompanionSettingsSectionState extends State<CompanionSettingsSection> {
  static const double _minimumPetSize = 2.0;
  static const double _maximumPetSize = 15.0;

  bool _isRenameDialogOpen = false;
  // Preview values show instantly in the UI; the controller is only called on commit (slider release / theme applied).
  bool _isApplyingTheme = false;
  String? _previewThemeId;
  double? _previewScale;
  double? _previewSensitivity;
  double? _previewOpacity;

  String get _displayedThemeId =>
      _previewThemeId ?? widget.controller.companionPetTheme;

  double get _displayedScale =>
      _previewScale ?? widget.controller.companionScale;

  // Snap to 0.5 steps.
  double _snapScale(double value) => (value * 2.0).roundToDouble() / 2.0;

  // Maps the 2..15 scale range to a 60-100% display factor.
  double _petSizeFactor(double value) {
    final normalized =
        ((value.clamp(_minimumPetSize, _maximumPetSize) - _minimumPetSize) /
                (_maximumPetSize - _minimumPetSize))
            .clamp(0.0, 1.0);
    return 0.60 + normalized * 0.40;
  }

  int _petSizePercent(double value) => (_petSizeFactor(value) * 100).round();

  void _previewPetSize(double value) {
    final snapped = _snapScale(value);
    if (_previewScale == snapped) return;
    setState(() => _previewScale = snapped);
  }

  Future<void> _commitPetSize(double value) async {
    final snapped = _snapScale(value);
    try {
      await widget.controller.changeScale(snapped);
    } finally {
      if (mounted) setState(() => _previewScale = null);
    }
  }

  double get _displayedSensitivity =>
      _previewSensitivity ?? widget.controller.gazeSensitivity;

  double get _displayedOpacity =>
      _previewOpacity ?? widget.controller.pipOpacity;

  Future<void> _commitOpacity(double value) async {
    try {
      await widget.controller.changePipOpacity(value);
    } finally {
      if (mounted) setState(() => _previewOpacity = null);
    }
  }

  String _sensitivityLabel(double value) {
    if (value < 0.34) return 'Relaxed';
    if (value > 0.66) return 'Keen';
    return 'Balanced';
  }

  Future<void> _commitSensitivity(double value) async {
    try {
      await widget.controller.changeGazeSensitivity(value);
    } finally {
      if (mounted) setState(() => _previewSensitivity = null);
    }
  }

  Future<void> _selectTheme(PetTheme theme) async {
    if (_isApplyingTheme || theme.id == _displayedThemeId) return;

    setState(() {
      _isApplyingTheme = true;
      _previewThemeId = theme.id;
    });

    try {
      await widget.controller.changeTheme(theme.id);
    } catch (error, stackTrace) {
      debugPrint('Unable to change companion theme: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (mounted) {
        setState(() {
          _isApplyingTheme = false;
          _previewThemeId = null;
        });
      }
    }
  }

  void _openBlobatarRenameDialog() {
    if (_isRenameDialogOpen) return;
    _isRenameDialogOpen = true;
    showBlobatarNameDialog(
      context,
      currentName: widget.controller.companionPetName,
      onSaved: (newName) {
        widget.controller.changePetName(newName);
      },
    ).whenComplete(() {
      if (mounted) {
        _isRenameDialogOpen = false;
      }
    });
  }

  void _handleRenameDialogRequest() {
    if (!mounted || _isRenameDialogOpen) return;
    if (widget.controller.consumePendingBlobatarNameDialogRequest()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isRenameDialogOpen) {
          _openBlobatarRenameDialog();
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    widget.controller.openBlobatarNameDialogNotifier.addListener(
      _handleRenameDialogRequest,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.controller.setPreviewMode(true);
        if (widget.controller.consumePendingBlobatarNameDialogRequest()) {
          _openBlobatarRenameDialog();
        }
      }
    });
  }

  @override
  void dispose() {
    widget.controller.openBlobatarNameDialogNotifier.removeListener(
      _handleRenameDialogRequest,
    );
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
                if (widget.controller.companionEnabled) ...[
                  _buildActiveCompanion(),
                  const SizedBox(height: 32),
                ],

                sectionHeader('Status'),
                buildCard([
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      widget.controller.companionStateExplanation,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  divider(),
                  toggleRow(
                    'Show companion',
                    'Floats on your screen in a small window',
                    widget.controller.companionEnabled,
                    (v) => widget.controller.toggleCompanion(v),
                  ),
                  if (widget.controller.companionEnabled) ...[
                    divider(),
                    toggleRow(
                      'Escalate if ignored',
                      'The companion cues first; the full reminder follows after 45 seconds',
                      sl<SettingsRepository>()
                          .currentSettings
                          .experience
                          .companionEscalates,
                      (v) {
                        final repo = sl<SettingsRepository>();
                        final cur = repo.currentSettings;
                        repo.save(
                          cur.copyWith(
                            experience: cur.experience.copyWith(
                              companionEscalates: v,
                            ),
                          ),
                        );
                        setState(() {});
                      },
                    ),
                  ],
                ]),

                if (widget.controller.companionEnabled) ...[
                  RepaintBoundary(child: _buildPetGallery()),
                  const SizedBox(height: 32),

                  if (!FlavorConfig.instance.isDev) ...[
                    sectionHeader('Streak recognition'),
                    _buildStreak(),
                    const SizedBox(height: 32),
                  ],

                  sectionHeader('Personalization'),
                  buildCard([
                    textFieldRow(
                      'Companion name',
                      widget.controller.companionPetName,
                      (v) => widget.controller.changePetName(v),
                    ),
                    divider(),
                    sliderRow(
                      'Pet size (${_petSizePercent(_displayedScale)}%)',
                      _displayedScale,
                      _previewPetSize,
                      onChangeEnd: (value) => unawaited(_commitPetSize(value)),
                      min: _minimumPetSize,
                      max: _maximumPetSize,
                    ),
                  ]),
                  sectionHeader('Floating window'),
                  buildCard([
                    dropdownRow(
                      'Backdrop',
                      widget.controller.pipBackgroundStyle,
                      const ['scene', 'none'],
                      (v) {
                        if (v != null) {
                          widget.controller.changePipBackgroundStyle(v);
                        }
                      },
                    ),
                    divider(),
                    toggleRow(
                      'Keep on screen',
                      'Off: it only appears during a break',
                      widget.controller.companionKeepOnScreen,
                      (v) => widget.controller.changeKeepOnScreen(v),
                    ),
                    divider(),
                    sliderRow(
                      'Window opacity (${(_displayedOpacity * 100).round()}%)${_displayedOpacity == 1.0 ? " (Opaque)" : ""}',
                      _displayedOpacity,
                      (v) => setState(() => _previewOpacity = v),
                      onChangeEnd: (v) => unawaited(_commitOpacity(v)),
                      min: 0.1,
                      max: 1.0,
                    ),
                    divider(),
                    toggleRow(
                      'Draggable area clickable',
                      'Off: the whole window ignores clicks',
                      widget.controller.pipDraggableClickable,
                      (v) => widget.controller.changePipDraggableClickable(v),
                    ),
                  ]),
                  sectionHeader('Looking and motion'),
                  buildCard([
                    toggleRow(
                      'Follow cursor',
                      'Eyes and head turn toward your pointer',
                      widget.controller.gazeEnabled,
                      (v) => widget.controller.changeGazeEnabled(v),
                    ),
                    if (widget.controller.gazeEnabled) ...[
                      divider(),
                      sliderRow(
                        'Sensitivity (${_sensitivityLabel(_displayedSensitivity)})',
                        _displayedSensitivity,
                        (v) => setState(() => _previewSensitivity = v),
                        onChangeEnd: (v) => unawaited(_commitSensitivity(v)),
                      ),
                    ],
                    divider(),
                    toggleRow(
                      'Idle animation',
                      'Breathing, blinking and glances while idle',
                      widget.controller.idleAnimationEnabled,
                      (v) => widget.controller.changeIdleAnimation(v),
                    ),
                    divider(),
                    toggleRow(
                      'Reactions',
                      'Celebrates finished breaks and perks up for reminders',
                      widget.controller.reactionsEnabled,
                      (v) => widget.controller.changeReactionsEnabled(v),
                    ),
                    divider(),
                    toggleRow(
                      'Reduce motion',
                      'No bouncing or wandering glances. Follows macOS Reduce Motion',
                      widget.controller.reducedMotionEnabled,
                      (v) => widget.controller.changeReducedMotion(v),
                    ),
                  ]),
                  sectionHeader('Behavior'),
                  buildCard([
                    toggleRow(
                      'Low-distraction focus mode',
                      'Less motion, no cursor chasing, click-through',
                      widget.controller.isLowDistractionMode,
                      (v) => widget.controller.setLowDistractionMode(v),
                    ),
                    divider(),
                    toggleRow(
                      'Click-through',
                      'Stays visible but ignores the mouse',
                      widget.controller.companionClickThrough,
                      (v) => widget.controller.changeClickThrough(v),
                    ),
                    divider(),
                    toggleRow(
                      'Wander around the screen',
                      'Strolls to a new spot near the edge now and then',
                      widget.controller.companionWanderingEnabled,
                      (v) => widget.controller.changeWandering(v),
                    ),
                  ]),

                  sectionHeader('Interaction'),
                  buildCard([
                    toggleRow(
                      'Petting',
                      'A pet button appears when you hover',
                      widget.controller.pettingEnabled,
                      (v) => widget.controller.changePettingEnabled(v),
                    ),
                    divider(),
                    toggleRow(
                      'Play',
                      'Offers a game when you hover',
                      widget.controller.ballThrowEnabled,
                      (v) => widget.controller.changeBallThrowEnabled(v),
                    ),
                    divider(),
                    toggleRow(
                      'Treats',
                      'Offers a treat when you hover',
                      widget.controller.treatEnabled,
                      (v) => widget.controller.changeTreatEnabled(v),
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
                    color: AppTheme.surface.withValues(alpha: 0.4),
                    child: Align(
                      alignment: Alignment.center,
                      child: Padding(
                        padding: EdgeInsets.zero,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceElevated.withValues(
                              alpha: 0.9,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMd,
                            ),
                            border: Border.all(color: AppTheme.border),
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
                                'Starting your companion',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
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

  Widget _buildStreak() {
    return AnimatedBuilder(
      animation: sl<CompanionStreakService>(),
      builder: (context, _) {
        final streakService = sl<CompanionStreakService>();
        final current = streakService.currentStreakDays;
        final highest = streakService.highestMilestone;
        final next = streakService.nextMilestone;
        final daysToNext = next != null ? next.days - current : null;

        return Padding(
          padding: const EdgeInsets.only(left: AppTheme.space4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$current',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w500,
                  fontFeatures: AppTheme.tabular,
                  color: current > 0
                      ? AppTheme.textPrimary
                      : AppTheme.textMuted,
                ),
              ),
              const SizedBox(width: AppTheme.space8),
              Flexible(
                child: Text(
                  [
                    'day streak',
                    ?highest?.label,
                    if (next != null && daysToNext != null && daysToNext > 0)
                      '$daysToNext ${daysToNext == 1 ? 'day' : 'days'} to "${next.label}"',
                  ].join(' · '),
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActiveCompanion() {
    final theme = PetTheme.getTheme(_displayedThemeId);
    final isBlobatar = theme.isBlobatar;
    final def = theme.avatarDefinition;
    final previewSize = 104.0 * _petSizeFactor(_displayedScale);

    return Row(
      children: [
        Container(
          width: 128,
          height: 128,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: isBlobatar
              ? BlobatarCompanionWidget(
                  name: widget.controller.companionPetName,
                  size: previewSize,
                  onTap: _openBlobatarRenameDialog,
                )
              : def != null
              ? CompanionPet(
                  key: ValueKey<String>(theme.id),
                  size: previewSize,
                  definition: def,
                  trackCursor: false,
                )
              : theme.basePath.endsWith('.svg')
              ? AvatarArtwork(
                  recipe: AvatarArtworkRecipe(assetKey: theme.basePath),
                  width: previewSize,
                  height: previewSize,
                  fit: BoxFit.contain,
                )
              : theme.basePath.isNotEmpty
              ? Image.asset(
                  theme.basePath,
                  width: previewSize,
                  height: previewSize,
                  fit: BoxFit.contain,
                )
              : Icon(CupertinoIcons.paw, size: 48, color: AppTheme.textMuted),
        ),
        const SizedBox(width: AppTheme.space24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.controller.companionPetName,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: AppTheme.space4),
              Text(
                isBlobatar
                    ? 'Blobatar, generative pet'
                    : '${theme.name} · ${theme.avatarDefinition?.species.category.displayName ?? theme.species.name}',
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
              if (isBlobatar) ...[
                const SizedBox(height: AppTheme.space16),
                MinimalButton(
                  isSecondary: true,
                  onPressed: _openBlobatarRenameDialog,
                  child: const Text('Name and morph'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSpeciesThumbnail(PetTheme theme) {
    final def = theme.avatarDefinition;
    if (def != null && hasAvatarScene(def.species.name)) {
      return FittedBox(
        fit: BoxFit.cover,
        child: Avatar3DView(
          preset: avatarPresetFor(def.species.name),
          size: 96,
          background: kSceneAuthoredBackground,
          showShadow: false,
          densityScale: 0.7,
          palette: def.palette == AvatarPalette.defaultPalette
              ? null
              : def.palette,
          style: avatarStyleFrom(def.parts),
        ),
      );
    }
    return AvatarArtwork(
      recipe: AvatarArtworkRecipe(assetKey: theme.basePath),
      fit: BoxFit.contain,
    );
  }

  Widget _buildPetGallery() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader(
          'Pets',
          subtitle: 'Select from 30+ 3D species and the generative Blobatar',
        ),
        const SizedBox(height: AppTheme.space4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 128,
            mainAxisExtent: 128,
            mainAxisSpacing: AppTheme.space8,
            crossAxisSpacing: AppTheme.space8,
          ),
          itemCount: PetTheme.themes.length,
          itemBuilder: (context, index) => _petTile(PetTheme.themes[index]),
        ),
      ],
    );
  }

  Widget _petTile(PetTheme theme) {
    final isSelected = _displayedThemeId == theme.id;
    final isLocked =
        !FlavorConfig.instance.isDev &&
        theme.requiredConsistencyDays > 0 &&
        (sl<CompanionStreakService>().currentStreakDays <
            theme.requiredConsistencyDays);

    return Tooltip(
      message: isLocked
          ? 'Requires a ${theme.requiredConsistencyDays}-day streak to unlock'
          : (theme.isBlobatar ? 'Blobatar: tap to select or rename' : ''),
      waitDuration: const Duration(milliseconds: 400),
      child: TapTarget(
        selected: isSelected,
        onTap: isLocked
            ? null
            : () {
                if (_isApplyingTheme) return;
                if (theme.isBlobatar && isSelected) {
                  _openBlobatarRenameDialog();
                } else {
                  unawaited(_selectTheme(theme));
                }
              },
        child: Container(
          padding: const EdgeInsets.all(AppTheme.space8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(
              color: isSelected ? AppTheme.accent : AppTheme.borderSubtle,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: Opacity(
                  opacity: isLocked ? 0.4 : 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                    child: SizedBox.expand(
                      child: theme.isBlobatar
                          ? Center(
                              child: BlobatarCompanionWidget(
                                name: widget.controller.companionPetName,
                                size: 56,
                                isInteractive: false,
                                animate: BlobatarAnimate.hover,
                              ),
                            )
                          : theme.avatarDefinition != null ||
                                theme.basePath.endsWith('.svg')
                          ? _buildSpeciesThumbnail(theme)
                          : Center(
                              child: Icon(
                                CupertinoIcons.paw,
                                size: 32,
                                color: AppTheme.textMuted,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.space4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLocked) ...[
                    Icon(
                      CupertinoIcons.lock,
                      size: 12,
                      color: AppTheme.textMuted,
                    ),
                    const SizedBox(width: AppTheme.space4),
                  ],
                  Flexible(
                    child: Text(
                      isLocked
                          ? '${theme.requiredConsistencyDays} days'
                          : theme.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isLocked
                            ? AppTheme.textMuted
                            : AppTheme.textPrimary,
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
}
