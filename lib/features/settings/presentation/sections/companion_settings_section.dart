import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:breakmate/core/config/flavor_config.dart';
import 'package:breakmate/features/companion/render/avatar_artwork.dart';
import 'package:breakmate/features/companion/render/avatar_artwork_recipe.dart';
import 'package:breakmate/features/companion/controllers/companion_overlay_controller.dart';
import 'package:breakmate/features/companion/domain/avatar_species.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:blobatar_flutter/blobatar_flutter.dart';
import 'package:breakmate/features/companion/presentation/widgets/blobatar_companion_widget.dart';
import 'package:breakmate/features/companion/presentation/widgets/blobatar_name_dialog.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
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
  static const double _minimumPetSize = 2.0;
  static const double _maximumPetSize = 15.0;

  bool _isRenameDialogOpen = false;
  bool _isApplyingTheme = false;
  String? _previewThemeId;
  double? _previewScale;
  double? _previewSensitivity;

  String get _displayedThemeId =>
      _previewThemeId ?? widget.controller.companionPetTheme;

  double get _displayedScale =>
      _previewScale ?? widget.controller.companionScale;

  double _snapScale(double value) => (value * 2.0).roundToDouble() / 2.0;

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

  /// A word for the slider position, so the number never has to be decoded.
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
                    'Enable your 3D companion to float seamlessly on your screen in Picture-in-Picture mode.',
                    widget.controller.companionEnabled,
                    (v) => widget.controller.toggleCompanion(v),
                  ),
                ]),

                if (widget.controller.companionEnabled) ...[
                  _buildPetGallery(),
                  const SizedBox(height: 32),

                  if (!FlavorConfig.instance.isDev) ...[
                    sectionHeader('Streak Recognition'),
                    _buildStreakCard(),
                    const SizedBox(height: 32),
                  ],

                  sectionHeader('Personalization'),
                  buildCard([
                    textFieldRow(
                      'Companion Name',
                      widget.controller.companionPetName,
                      (v) => widget.controller.changePetName(v),
                    ),
                    divider(),
                    sliderRow(
                      'Pet Size (${_petSizePercent(_displayedScale)}%)',
                      _displayedScale,
                      _previewPetSize,
                      onChangeEnd: (value) => unawaited(_commitPetSize(value)),
                      min: _minimumPetSize,
                      max: _maximumPetSize,
                    ),
                  ]),

                  sectionHeader('Floating Window'),
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
                      'Keep On Screen',
                      'Your companion stays out all the time. Turn this off and '
                          'it only appears while a break is running.',
                      widget.controller.companionKeepOnScreen,
                      (v) => widget.controller.changeKeepOnScreen(v),
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

                  const SizedBox(height: 32),
                  sectionHeader('Looking & Motion'),
                  buildCard([
                    toggleRow(
                      'Follow Cursor',
                      'Eyes and head turn toward your pointer, and settle '
                          'when it stops. Nothing is recorded or sent anywhere.',
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
                      'Idle Animation',
                      'Gentle breathing, blinking and occasional glances '
                          'while nothing is happening.',
                      widget.controller.idleAnimationEnabled,
                      (v) => widget.controller.changeIdleAnimation(v),
                    ),
                    divider(),
                    toggleRow(
                      'Reactions',
                      'Celebrates a finished break and perks up for a break '
                          'reminder. Never makes a sound or a notification.',
                      widget.controller.reactionsEnabled,
                      (v) => widget.controller.changeReactionsEnabled(v),
                    ),
                    divider(),
                    toggleRow(
                      'Reduce Motion',
                      'No bouncing, recoil or wandering glances. Also on '
                          'automatically when macOS Reduce Motion is on.',
                      widget.controller.reducedMotionEnabled,
                      (v) => widget.controller.changeReducedMotion(v),
                    ),
                  ]),

                  const SizedBox(height: 32),
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
                      'Wander Around the Screen',
                      'Every so often the pet strolls to a new spot near the '
                          'edge of your display. It never moves while you are '
                          'hovering over it or dragging it.',
                      widget.controller.companionWanderingEnabled,
                      (v) => widget.controller.changeWandering(v),
                    ),
                  ]),

                  const SizedBox(height: 32),

                  sectionHeader('Interaction Features'),
                  buildCard([
                    toggleRow(
                      'Petting & Affection',
                      'Offers a "pet" button when you hover the companion, and '
                          'lets you scratch it by clicking.',
                      widget.controller.pettingEnabled,
                      (v) => widget.controller.changePettingEnabled(v),
                    ),
                    divider(),
                    toggleRow(
                      'Play',
                      'Offers a game when you hover the companion. It stays '
                          'wound up for a while afterwards.',
                      widget.controller.ballThrowEnabled,
                      (v) => widget.controller.changeBallThrowEnabled(v),
                    ),
                    divider(),
                    toggleRow(
                      'Treats',
                      'Offers a treat when you hover the companion. The '
                          'quickest way to win it over.',
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
                    color: Colors.black.withValues(alpha: 0.15),
                    // Near the top, where the switch that was just pressed is,
                    // rather than the middle of a page that may be scrolled.
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 120),
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
                                'Starting your companion...',
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
              ),
          ],
        );
      },
    );
  }

  Widget _buildHeroHeader() {
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
                        // The name the user gave their companion, as chosen.
                        widget.controller.companionPetName.trim().isEmpty
                            ? 'Companion'
                            : widget.controller.companionPetName,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.5,
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
                      if (next != null &&
                          daysToNext != null &&
                          daysToNext > 0) ...[
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

  Widget _buildActiveCompanionShowcase() {
    final theme = PetTheme.getTheme(_displayedThemeId);
    final isBlobatar = theme.isBlobatar;
    final def = theme.avatarDefinition;
    final previewSize = 124.0 * _petSizeFactor(_displayedScale);

    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.accentColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentColor.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left: Clean full SVG or Blobatar showcase
          Container(
            width: 140,
            height: 140,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (isBlobatar)
                  Center(
                    child: BlobatarCompanionWidget(
                      name: widget.controller.companionPetName,
                      size: previewSize,
                      onTap: _openBlobatarRenameDialog,
                    ),
                  )
                else if (def != null)
                  Center(
                    child: AvatarArtwork.definition(
                      def,
                      width: previewSize,
                      height: previewSize,
                      fit: BoxFit.contain,
                    ),
                  )
                else if (theme.basePath.endsWith('.svg'))
                  Center(
                    child: AvatarArtwork(
                      recipe: AvatarArtworkRecipe(assetKey: theme.basePath),
                      width: previewSize,
                      height: previewSize,
                      fit: BoxFit.contain,
                    ),
                  )
                else if (theme.basePath.isNotEmpty)
                  Center(
                    child: Image.asset(
                      theme.basePath,
                      width: previewSize,
                      height: previewSize,
                      fit: BoxFit.contain,
                    ),
                  )
                else
                  Icon(
                    Icons.pets_rounded,
                    size: 64,
                    color: AppTheme.accentColor,
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.18),
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Text(
                      theme.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // Right: Pet Details & Actions
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ACTIVE COMPANION',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.accentColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  widget.controller.companionPetName,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isBlobatar
                      ? 'Blobatar · GENERATIVE DYNAMIC PET'
                      : '${theme.name} · ${theme.species.name.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                if (isBlobatar)
                  FilledButton.icon(
                    onPressed: _openBlobatarRenameDialog,
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: const Text('Name & Morph Blob'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _speciesThumbnailAsset(PetTheme theme) {
    final species = theme.avatarDefinition?.species;
    return switch (species) {
      AvatarSpecies.panda ||
      AvatarSpecies.redPanda ||
      AvatarSpecies.raccoon => 'assets/avatars/species/bear.thumbnail.png',
      AvatarSpecies.wolf => 'assets/avatars/species/dog.thumbnail.png',
      AvatarSpecies.guineaPig =>
        'assets/avatars/species/guinea-pig.thumbnail.png',
      final AvatarSpecies species =>
        'assets/avatars/species/${species.name}.thumbnail.png',
      null => theme.basePath,
    };
  }

  Widget _buildSpeciesThumbnail(PetTheme theme) {
    return RepaintBoundary(
      child: Image.asset(
        _speciesThumbnailAsset(theme),
        fit: BoxFit.cover,
        alignment: Alignment.center,
        cacheWidth: 256,
        cacheHeight: 256,
        filterQuality: FilterQuality.medium,
        isAntiAlias: true,
        errorBuilder: (_, _, _) => Center(
          child: Icon(Icons.pets_rounded, size: 34, color: AppTheme.textMuted),
        ),
      ),
    );
  }

  Widget _buildPetGallery() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildActiveCompanionShowcase(),
        const SizedBox(height: 16),
        sectionHeader(
          '3D Pet Gallery',
          subtitle:
              'Select from 30+ OneWorks 3D species and generative Blobatar',
        ),

        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.95,
          ),
          itemCount: PetTheme.themes.length,
          itemBuilder: (context, index) {
            final theme = PetTheme.themes[index];
            final isSelected = _displayedThemeId == theme.id;
            // Every pet is available in the dev flavor; streak gating only
            // applies to real builds.
            final isLocked =
                !FlavorConfig.instance.isDev &&
                theme.requiredConsistencyDays > 0 &&
                (sl<CompanionStreakService>().currentStreakDays <
                    theme.requiredConsistencyDays);

            return Tooltip(
              message: isLocked
                  ? 'Requires a ${theme.requiredConsistencyDays}-day streak to unlock'
                  : (theme.isBlobatar
                        ? 'Blobatar: tap to select or rename'
                        : ''),
              waitDuration: const Duration(milliseconds: 400),
              child: GestureDetector(
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
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isSelected
                          ? [
                              AppTheme.accentColor.withValues(alpha: 0.22),
                              AppTheme.accentColor.withValues(alpha: 0.08),
                            ]
                          : [
                              AppTheme.surfaceElevated,
                              AppTheme.accentColor.withValues(alpha: 0.05),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.accentColor
                          : AppTheme.border,
                      width: isSelected ? 2.5 : 1,
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
                        : null,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Full-bleed authored species artwork for a fast, reliable
                      // thumbnail. The full avatar renderer is reserved for the
                      // larger active-companion preview.
                      if (theme.isBlobatar)
                        Center(
                          child: BlobatarCompanionWidget(
                            name: widget.controller.companionPetName,
                            size: 64,
                            isInteractive: false,
                            animate: BlobatarAnimate.hover,
                          ),
                        )
                      else if (theme.avatarDefinition != null ||
                          theme.basePath.endsWith('.svg'))
                        _buildSpeciesThumbnail(theme)
                      else
                        Center(
                          child: Icon(
                            Icons.pets_rounded,
                            size: 40,
                            color: isSelected
                                ? AppTheme.accentColor
                                : AppTheme.textMuted,
                          ),
                        ),

                      // Bottom banner keeps names readable over every authored
                      // background without hiding the colourful artwork.
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 5,
                            horizontal: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.28),
                            border: Border(
                              top: BorderSide(
                                color: Colors.white.withValues(alpha: 0.12),
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isSelected) ...[
                                Container(
                                  width: 5,
                                  height: 5,
                                  margin: const EdgeInsets.only(right: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                              Flexible(
                                child: Text(
                                  theme.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: isSelected
                                        ? AppTheme.accentColor
                                        : Colors.white,
                                    letterSpacing: 0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (isLocked) ...[
                        Positioned.fill(
                          child: ColoredBox(
                            color: Colors.black.withValues(alpha: 0.16),
                          ),
                        ),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.42),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.22),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  CupertinoIcons.lock_fill,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${theme.requiredConsistencyDays} days',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
