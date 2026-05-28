import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:math' as dart_math;
import 'package:breakmate/features/companion/controllers/companion_overlay_controller.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/domain/pet_type.dart';
import 'package:breakmate/core/native/native_bridge.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/shared/widgets/app_dropdown.dart';

class CompanionSettingsSection extends StatelessWidget {
  final CompanionOverlayController controller;

  const CompanionSettingsSection({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return _buildCompanion();
  }

  Widget _buildCompanion() {
    final controller = this.controller;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionHeader('Companion'),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 24),
              child: Text(
                'Spawn a cute virtual pet that sits on your desktop, wanders around, and reacts to your focus and break sessions.',
                style: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.8),
                  fontSize: 13,
                  fontFamily: 'Satoshi',
                ),
              ),
            ),
            buildCard([
              toggleRow(
                'Enable Companion',
                'Show or hide your desktop pet companion overlay',
                controller.companionEnabled,
                (v) => controller.toggleCompanion(v),
              ),
            ]),
            if (controller.companionEnabled) ...[
              const SizedBox(height: 32),
              sectionHeader('Companion'),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 16),
                child: Text(
                  'Choose the theme and look of your animated pet companion.',
                  style: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.8),
                    fontSize: 13,
                    fontFamily: 'Satoshi',
                  ),
                ),
              ),
              _buildCompanionThemeDropdown(controller),
              const SizedBox(height: 32),
              sectionHeader('Overlay Settings'),
              buildCard([
                sliderRow(
                  'Scale Factor (${controller.companionScale.toStringAsFixed(1)}x)',
                  controller.companionScale,
                  (v) {
                    final snapped = (v * 2.0).roundToDouble() / 2.0;
                    controller.changeScale(snapped);
                  },
                  min: 2.0,
                  max: 8.0,
                ),
                divider(),
                toggleRow(
                  'Ignore Mouse Clicks',
                  'Enable click-through mode so you can interact with windows behind the pet',
                  controller.companionClickThrough,
                  (v) => controller.changeClickThrough(v),
                ),
                divider(),
                toggleRow(
                  'Follow Mouse Cursor',
                  'Let the pet companion follow and chase your mouse cursor dynamically',
                  controller.companionFollowMouse,
                  (v) => controller.changeFollowMouse(v),
                ),
              ]),
              const SizedBox(height: 16),
              // Instant refresh button ΓÇö forces a clean re-spawn with all current settings
              buildCard([
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.sync, size: 18, color: AppTheme.accentColor),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Refresh Companion',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Re-spawn companion with all current settings applied instantly',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 32,
                        child: ElevatedButton.icon(
                          onPressed: () => controller.refreshCompanion(),
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Update'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 32),
              sectionHeader('Test Interactions'),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 16),
                child: Text(
                  'Trigger instant animations to see how your pet reacts to different app states.',
                  style: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.8),
                    fontSize: 13,
                    fontFamily: 'Satoshi',
                  ),
                ),
              ),
              _buildCompanionTestInteractions(controller),
            ],
          ],
        );
      },
    );
  }

  Widget _buildCompanionThemeDropdown(CompanionOverlayController controller) {
    return buildCard([
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Companion',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pet: ${controller.companionPetName}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.accentColor,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Satoshi',
                  ),
                ),
              ],
            ),
            const Spacer(),
            AppDropdown<String>(
              value: controller.companionPetTheme,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  controller.changeTheme(newValue);
                }
              },
              items: PetTheme.themes.map((theme) {
                final species = theme.species;
                final isSelected = controller.companionPetTheme == theme.id;

                Color tagColor = Colors.orange;
                switch (species) {
                  case PetSpecies.dog:
                    tagColor = Colors.blue;
                    break;
                  case PetSpecies.rabbit:
                    tagColor = Colors.pink;
                    break;
                  case PetSpecies.fox:
                    tagColor = Colors.deepOrange;
                    break;
                  case PetSpecies.dragon:
                    tagColor = Colors.red;
                    break;
                  case PetSpecies.cat:
                    tagColor = Colors.orange;
                    break;
                }

                return AppDropdownItem<String>(
                  value: theme.id,
                  label: theme.name,
                  customChild: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: tagColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          species.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: tagColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        theme.name,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          fontFamily: 'Satoshi',
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(width: 10),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: () {
                final currentTheme = PetTheme.getTheme(
                  controller.companionPetTheme,
                );
                final species = currentTheme.species;
                final random = dart_math.Random();
                final List<String> names;
                switch (species) {
                  case PetSpecies.dog:
                    names = CompanionOverlayController.dogNames;
                    break;
                  case PetSpecies.rabbit:
                    names = CompanionOverlayController.rabbitNames;
                    break;
                  case PetSpecies.fox:
                    names = CompanionOverlayController.foxNames;
                    break;
                  case PetSpecies.dragon:
                    names = CompanionOverlayController.dragonNames;
                    break;
                  case PetSpecies.cat:
                    names = CompanionOverlayController.catNames;
                    break;
                }
                final randomName = names[random.nextInt(names.length)];
                controller.changePetName(randomName);
              },
              child: Icon(
                CupertinoIcons.refresh_bold,
                size: 14,
                color: AppTheme.accentColor,
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _buildCompanionTestInteractions(
    CompanionOverlayController controller,
  ) {
    final themeId = controller.companionPetTheme;
    final petTheme = PetTheme.getTheme(themeId);
    final species = petTheme.species;

    final List<Map<String, dynamic>> interactions;

    if (themeId == PetTheme.keyPixelCat) {
      interactions = [
        {'label': 'Walk Around', 'icon': CupertinoIcons.paw, 'state': 'walk'},
        {
          'label': 'Excited Run',
          'icon': CupertinoIcons.wind,
          'state': 'excited',
        },
        {
          'label': 'Attack Mode',
          'icon': CupertinoIcons.shield_fill,
          'state': 'angry',
        },
        {
          'label': 'Alert Jump',
          'icon': CupertinoIcons.bell_fill,
          'state': 'notification',
        },
        {
          'label': 'Sad Hurt',
          'icon': CupertinoIcons.bandage_fill,
          'state': 'sad',
        },
        {
          'label': 'Celebrate Jump',
          'icon': CupertinoIcons.sparkles,
          'state': 'celebrate',
        },
        {'label': 'Idle', 'icon': CupertinoIcons.hourglass, 'state': 'idle'},
      ];
    } else if (themeId == PetTheme.keyLargeCat) {
      interactions = [
        {'label': 'Run Around', 'icon': CupertinoIcons.paw, 'state': 'walk'},
        {
          'label': 'Sad Fall',
          'icon': CupertinoIcons.cloud_rain_fill,
          'state': 'sad',
        },
        {
          'label': 'Jump Alert',
          'icon': CupertinoIcons.bell_fill,
          'state': 'notification',
        },
        {'label': 'Idle', 'icon': CupertinoIcons.hourglass, 'state': 'idle'},
      ];
    } else if (themeId == PetTheme.keyCat1 ||
        themeId == PetTheme.keyCat2 ||
        themeId == PetTheme.keyCat4 ||
        themeId == PetTheme.keyCat5 ||
        themeId == PetTheme.keyCat6 ||
        themeId == PetTheme.keyRabbit) {
      interactions = [
        {
          'label': species == PetSpecies.rabbit ? 'Hop Around' : 'Walk Around',
          'icon': CupertinoIcons.paw,
          'state': 'walk',
        },
        {
          'label': 'Take Nap',
          'icon': CupertinoIcons.moon_zzz_fill,
          'state': 'sleep',
        },
        {
          'label': 'Celebrate Stretch',
          'icon': CupertinoIcons.sparkles,
          'state': 'celebrate',
        },
        {
          'label': species == PetSpecies.rabbit ? 'Nose Twitch' : 'Angry Itch',
          'icon': CupertinoIcons.ant_fill,
          'state': 'angry',
        },
        {
          'label': species == PetSpecies.rabbit ? 'Perk Ears' : 'Meow Alert',
          'icon': CupertinoIcons.chat_bubble_2_fill,
          'state': 'notification',
        },
        {
          'label': 'Lick Paw',
          'icon': CupertinoIcons.heart_fill,
          'state': 'lick1',
        },
        {
          'label': 'Lick Fur',
          'icon': CupertinoIcons.sparkles,
          'state': 'lick2',
        },
        {'label': 'Idle', 'icon': CupertinoIcons.hourglass, 'state': 'idle'},
      ];
    } else if (themeId == PetTheme.keyCat3) {
      interactions = [
        {'label': 'Walk Around', 'icon': CupertinoIcons.paw, 'state': 'walk'},
        {
          'label': 'Take Nap',
          'icon': CupertinoIcons.moon_zzz_fill,
          'state': 'sleep',
        },
        {
          'label': 'Celebrate Stretch',
          'icon': CupertinoIcons.sparkles,
          'state': 'celebrate',
        },
        {
          'label': 'Angry Meow',
          'icon': CupertinoIcons.chat_bubble_2_fill,
          'state': 'angry',
        },
        {
          'label': 'Meow Alert',
          'icon': CupertinoIcons.bell_fill,
          'state': 'notification',
        },
        {
          'label': 'Lick Paw',
          'icon': CupertinoIcons.heart_fill,
          'state': 'lick1',
        },
        {
          'label': 'Lick Fur',
          'icon': CupertinoIcons.sparkles,
          'state': 'lick2',
        },
        {'label': 'Idle', 'icon': CupertinoIcons.hourglass, 'state': 'idle'},
      ];
    } else if (species == PetSpecies.dog) {
      interactions = [
        {'label': 'Walk Around', 'icon': CupertinoIcons.paw, 'state': 'walk'},
        {
          'label': 'Take Nap',
          'icon': CupertinoIcons.moon_zzz_fill,
          'state': 'sleep',
        },
        {
          'label': 'Excited Run',
          'icon': CupertinoIcons.wind,
          'state': 'excited',
        },
        {
          'label': 'Sad Whimper',
          'icon': CupertinoIcons.cloud_rain_fill,
          'state': 'sad',
        },
        {
          'label': 'Celebrate Jump',
          'icon': CupertinoIcons.sparkles,
          'state': 'celebrate',
        },
        {
          'label': 'Bark Alert',
          'icon': CupertinoIcons.bell_fill,
          'state': 'notification',
        },
        {
          'label': 'Angry Growl',
          'icon': CupertinoIcons.flame_fill,
          'state': 'angry',
        },
        {'label': 'Idle', 'icon': CupertinoIcons.hourglass, 'state': 'idle'},
      ];
    } else {
      // Fox, Dragon, etc.
      interactions = [
        {
          'label': species == PetSpecies.dragon ? 'Glide / Fly' : 'Walk Around',
          'icon': CupertinoIcons.paw,
          'state': 'walk',
        },
        {
          'label': 'Take Nap',
          'icon': CupertinoIcons.moon_zzz_fill,
          'state': 'sleep',
        },
        {
          'label': 'Excited Run',
          'icon': CupertinoIcons.wind,
          'state': 'excited',
        },
        {
          'label': 'Sad Pout',
          'icon': CupertinoIcons.cloud_rain_fill,
          'state': 'sad',
        },
        {
          'label': 'Celebrate',
          'icon': CupertinoIcons.sparkles,
          'state': 'celebrate',
        },
        {
          'label': species == PetSpecies.dragon
              ? 'Breathe Fire'
              : 'Hiss / Angry',
          'icon': CupertinoIcons.flame_fill,
          'state': 'angry',
        },
        {
          'label': 'Jump Alert',
          'icon': CupertinoIcons.bell_fill,
          'state': 'notification',
        },
        {'label': 'Idle', 'icon': CupertinoIcons.hourglass, 'state': 'idle'},
      ];
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: interactions.map((inter) {
        return _buildInteractionButton(
          inter['label'] as String,
          inter['icon'] as IconData,
          inter['state'] as String,
        );
      }).toList(),
    );
  }

  Widget _buildInteractionButton(String label, IconData icon, String state) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () async {
        await NativeBridge.triggerCompanionState(state);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppTheme.accentColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
                fontFamily: 'Satoshi',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
