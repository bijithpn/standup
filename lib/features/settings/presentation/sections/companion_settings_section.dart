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
  State<CompanionSettingsSection> createState() => _CompanionSettingsSectionState();
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
              toggleRow(
                'Show Companion',
                'Enable your desktop pet to see it wandering around your screen.',
                widget.controller.companionEnabled,
                (v) => widget.controller.toggleCompanion(v),
              ),
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

              sectionHeader('Behavior'),
              buildCard([
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  sectionHeader('Animation Lab'),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildSyncCard(),
                  ),
                ],
              ),
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
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              Icons.pets_rounded,
              size: 100,
              color: AppTheme.accentColor.withValues(alpha: 0.03),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
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
                    const SizedBox(height: 10),
                    Text(
                      widget.controller.companionEnabled ? widget.controller.companionPetName : 'Desktop Companion',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Currently enjoying the ${currentTheme.name} theme. Switch variants below to find your perfect work buddy.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              if (widget.controller.companionEnabled)
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: CompanionSpriteWidget(
                      petTheme: currentTheme,
                      animationState: PetAnimationState.idle,
                      scale: 2.0,
                    ),
                  ),
                ),
            ],
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
        sectionHeader('Pet Gallery', subtitle: 'Select a variant to change your companion instantly'),
        
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: PetTheme.themes.map((theme) {
            final isSelected = widget.controller.companionPetTheme == theme.id;
            
            return GestureDetector(
              onTap: () => widget.controller.changeTheme(theme.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutExpo,
                width: 76,
                height: 86,
                decoration: BoxDecoration(
                  color: isSelected 
                      ? AppTheme.accentColor.withValues(alpha: 0.15) 
                      : AppTheme.surfaceElevated.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
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
                        child: Transform.scale(
                          scale: isSelected ? 1.2 : 1.0,
                          child: CompanionSpriteWidget(
                            petTheme: theme,
                            animationState: isSelected 
                                ? PetAnimationState.excited 
                                : PetAnimationState.idle,
                            scale: 1.5,
                            isStatic: true,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
                      child: Text(
                        theme.name.replaceAll('Studio ', '').replaceAll('Cat', '').trim(),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                          color: isSelected ? Colors.white : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
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
          Icon(CupertinoIcons.arrow_2_circlepath, color: Colors.white, size: 18),
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
    final themeId = widget.controller.companionPetTheme;
    final List<Map<String, dynamic>> interactions;

    if (themeId == PetTheme.keyPixelCat) {
      interactions = [
        {'label': 'Walk', 'icon': CupertinoIcons.paw, 'state': 'walk'},
        {'label': 'Run', 'icon': CupertinoIcons.wind, 'state': 'excited'},
        {'label': 'Attack', 'icon': CupertinoIcons.shield_fill, 'state': 'angry'},
        {'label': 'Alert', 'icon': CupertinoIcons.bell_fill, 'state': 'notification'},
        {'label': 'Hurt', 'icon': CupertinoIcons.bandage_fill, 'state': 'sad'},
        {'label': 'Win', 'icon': CupertinoIcons.sparkles, 'state': 'celebrate'},
      ];
    } else if (themeId == PetTheme.keyLargeCat) {
      interactions = [
        {'label': 'Run', 'icon': CupertinoIcons.paw, 'state': 'walk'},
        {'label': 'Fall', 'icon': CupertinoIcons.cloud_rain_fill, 'state': 'sad'},
        {'label': 'Jump', 'icon': CupertinoIcons.bell_fill, 'state': 'notification'},
        {'label': 'Idle', 'icon': CupertinoIcons.hourglass, 'state': 'idle'},
      ];
    } else {
      interactions = [
        {'label': 'Walk', 'icon': CupertinoIcons.paw, 'state': 'walk'},
        {'label': 'Nap', 'icon': CupertinoIcons.moon_zzz_fill, 'state': 'sleep'},
        {'label': 'Stretch', 'icon': CupertinoIcons.sparkles, 'state': 'celebrate'},
        {'label': 'Angry', 'icon': CupertinoIcons.flame_fill, 'state': 'angry'},
        {'label': 'Alert', 'icon': CupertinoIcons.bell_fill, 'state': 'notification'},
        {'label': 'Lick', 'icon': CupertinoIcons.heart_fill, 'state': 'lick1'},
      ];
    }

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
            onTap: () => NativeBridge.triggerCompanionState(inter['state'] as String),
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
                  Icon(inter['icon'] as IconData, size: 16, color: AppTheme.accentColor),
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
