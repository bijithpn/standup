import 'dart:io';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/companion/ai/pet_behavior_brain.dart';
import 'package:breakmate/features/companion/assets/pet_asset_loader.dart';
import 'package:breakmate/features/companion/domain/avatar_definition.dart';
import 'package:breakmate/features/companion/domain/avatar_palette.dart';
import 'package:breakmate/features/companion/domain/avatar_species.dart';
import 'package:breakmate/features/companion/domain/behavior_engine_models.dart';
import 'package:breakmate/features/companion/domain/pet_mood.dart';
import 'package:breakmate/features/companion/domain/pet_needs.dart';
import 'package:breakmate/features/companion/domain/pet_personality.dart';
import 'package:breakmate/features/companion/domain/pet_state_machine.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/engine/avatar_engine_controller.dart';
import 'package:breakmate/features/companion/flame/companion_game.dart';
import 'package:breakmate/features/companion/services/pet_companion_service.dart';
import 'package:breakmate/features/companion/services/pet_navigation_service.dart';
import 'package:breakmate/features/companion/services/physics_simulator.dart';
import 'package:breakmate/features/companion/services/settings_persistence.dart';
import 'package:breakmate/features/companion/services/throwable_object_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync(
      'companion_full_system_test_',
    );
    PetAssetLoader.clearCache();
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Full System End-to-End: OneWorks 3D Avatar Companion', () {
    test(
      'initializes complete 3D OneWorks avatar companion system with brain, state machine, and navigation',
      () async {
        final avatarDef = AvatarDefinition.fromSeed(
          'full-system-test-seed',
          species: AvatarSpecies.fox,
        );
        final theme = PetTheme.avatar(
          id: 'avatar_fox',
          name: 'Fox (3D)',
          definition: avatarDef,
        );

        final stateMachine = PetStateMachine(
          personality: PetPersonality.friendly,
        );
        final brain = PetBehaviorBrain();
        final navigation = PetNavigationService();
        final needsEngine = NeedsEngine();
        final physicsSimulator = PhysicsSimulator();
        final throwableManager = ThrowableObjectManager(
          physicsSimulator: physicsSimulator,
        );

        final profile = CompanionGame.getProfileFromTheme(theme);
        expect(profile.theme, isNotNull);
        expect(profile.theme!.avatarDefinition, isNotNull);
        expect(
          profile.theme!.avatarDefinition!.species,
          equals(AvatarSpecies.fox),
        );

        final service = PetCompanionService(
          stateMachine: stateMachine,
          brain: brain,
          navigation: navigation,
          profile: profile,
          needsEngine: needsEngine,
          throwableManager: throwableManager,
        );

        expect(service.profile.id, equals('avatar_fox'));
        expect(service.currentState, equals(PetState.idle));
        expect(service.mood.mood, equals(PetMood.relaxed));
      },
    );

    test(
      'simulates needs decay, mood transitions, and state machine reactions',
      () {
        final avatarDef = AvatarDefinition.fromSpecies(AvatarSpecies.cat);
        final theme = PetTheme.avatar(definition: avatarDef);
        final stateMachine = PetStateMachine();
        final brain = PetBehaviorBrain();
        final navigation = PetNavigationService();
        final needsEngine = NeedsEngine();

        final service = PetCompanionService(
          stateMachine: stateMachine,
          brain: brain,
          navigation: navigation,
          profile: CompanionGame.getProfileFromTheme(theme),
          needsEngine: needsEngine,
        );

        // Verify petting triggers affectionate reaction and raises affection / happiness
        service.onPetting();
        expect(service.currentState, equals(PetState.affectionate));

        // Simulate hunger and feeding treat
        service.onFedTreat();
        expect(service.currentState, equals(PetState.eating));

        // Test needs decay towards sleep
        final lowEnergyNeeds = const PetNeeds(
          energy: 0.1,
          hunger: 20.0,
          boredom: 20.0,
          happiness: 50.0,
        );
        final mood = PetMoodCalculator.fromNeeds(lowEnergyNeeds);
        expect(mood, equals(PetMood.tired));
      },
    );

    test(
      'continuous desktop cursor gaze tracking calculates lookAt vectors and updates avatar engine',
      () async {
        final avatarController = AvatarEngineController();

        // Cursor directly in center of pet
        final centerGaze = avatarController.calculateGaze(
          cursorScreenPosition: const Offset(400, 300),
          petScreenPosition: const Offset(400, 300),
        );
        expect(centerGaze.dx, closeTo(0.0, 0.01));
        expect(centerGaze.dy, closeTo(0.0, 0.01));

        // Cursor to top-right
        final trGaze = avatarController.calculateGaze(
          cursorScreenPosition: const Offset(700, 100),
          petScreenPosition: const Offset(400, 300),
        );
        expect(trGaze.dx, greaterThan(0.0));
        expect(trGaze.dy, lessThan(0.0));

        // Update avatar controller gaze
        await avatarController.setLookAt(trGaze.dx, trGaze.dy);
        expect(avatarController.currentLookAt.dx, closeTo(trGaze.dx, 0.01));
        expect(avatarController.currentLookAt.dy, closeTo(trGaze.dy, 0.01));
      },
    );

    test(
      'settings persistence saves and restores full 3D avatar definitions, seeds, species, and palettes across restarts',
      () async {
        final configFile =
            '${tempDir.path}${Platform.pathSeparator}pet_config_v2.json';
        final persistence = SettingsPersistence(configPathOverride: configFile);

        final customPalette = const AvatarPalette(
          name: 'Electric Neon',
          primary: '#00ffcc',
          secondary: '#ff007f',
          accent: '#ffff00',
          snout: '#ffffff',
          ears: '#ff007f',
          eyes: '#00ffcc',
          belly: '#ffffff',
        );

        final customDef = AvatarDefinition(
          schemaVersion: 1,
          species: AvatarSpecies.capybara,
          palette: customPalette,
          pattern: 'stripes',
          seed: 'breakmate-capybara-neon-seed',
          scale: 1.5,
          yaw: 0.78,
          parts: {'hat': 'party_hat', 'glasses': 'sunglasses'},
        );

        final config = PetConfigV2(
          mode: PetMode.freeRoam,
          pinnedDisplayId: 'display_1',
          constraintWindowBounds: const Rect.fromLTWH(50, 50, 400, 400),
          lastAnchorPoint: const Offset(200, 300),
          themeId: 'avatar_capybara',
          petName: 'Barnaby',
          scale: 7.5,
          avatarDefinition: customDef,
        );

        persistence.scheduleWrite(config);
        await persistence.flushPendingWrite();

        // Verify file was written to disk
        expect(File(configFile).existsSync(), isTrue);

        // Simulate app restart by creating a new SettingsPersistence instance
        final restartedPersistence = SettingsPersistence(
          configPathOverride: configFile,
        );
        final restoredConfig = restartedPersistence.loadSync();

        expect(restoredConfig.petName, equals('Barnaby'));
        expect(restoredConfig.themeId, equals('avatar_capybara'));
        expect(restoredConfig.scale, equals(7.5));
        expect(restoredConfig.avatarDefinition, isNotNull);
        expect(
          restoredConfig.avatarDefinition!.species,
          equals(AvatarSpecies.capybara),
        );
        expect(
          restoredConfig.avatarDefinition!.seed,
          equals('breakmate-capybara-neon-seed'),
        );
        expect(
          restoredConfig.avatarDefinition!.palette.name,
          equals('Electric Neon'),
        );
        expect(
          restoredConfig.avatarDefinition!.palette.primary,
          equals('#00ffcc'),
        );
        expect(
          restoredConfig.avatarDefinition!.parts['hat'],
          equals('party_hat'),
        );
        expect(
          restoredConfig.avatarDefinition!.parts['glasses'],
          equals('sunglasses'),
        );

        // Test direct helper method saveAvatarDefinition
        final newFoxDef = AvatarDefinition.fromSeed(
          'quick-fox-seed',
          species: AvatarSpecies.fox,
        );
        restartedPersistence.saveAvatarDefinition(newFoxDef);
        await restartedPersistence.flushPendingWrite();

        final reloadedPersistence = SettingsPersistence(
          configPathOverride: configFile,
        );
        final reloadedConfig = reloadedPersistence.loadSync();
        expect(reloadedConfig.themeId, equals('avatar_fox'));
        expect(
          reloadedConfig.avatarDefinition?.species,
          equals(AvatarSpecies.fox),
        );
        expect(reloadedConfig.avatarDefinition?.seed, equals('quick-fox-seed'));
      },
    );

    test(
      'PetAssetLoader provides graceful backward compatibility for 3D avatar themes alongside sprite/environment assets',
      () async {
        // 1. 3D Avatar Theme validation
        final avatarTheme = PetTheme.avatar(species: AvatarSpecies.panda);
        final avatarIssues = await PetAssetLoader.validateTheme(avatarTheme);
        expect(
          avatarIssues,
          isEmpty,
          reason: 'Avatar theme validation should pass cleanly',
        );

        // 2. 3D Avatar animation loading returns empty or valid map gracefully without throwing
        final avatarProfile = CompanionGame.getProfileFromTheme(avatarTheme);
        final avatarAnims = await PetAssetLoader.loadAnimations(avatarProfile);
        expect(avatarAnims, isNotNull);

        // 3. Pre-caching avatar theme does not throw
        await expectLater(PetAssetLoader.preCache(avatarProfile), completes);

        // 4. Pre-caching backgrounds remains fully functional
        await expectLater(PetAssetLoader.preCacheBackgrounds(), completes);
      },
    );
  });
}
