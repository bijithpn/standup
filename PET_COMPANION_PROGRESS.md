# Pet Companion Framework - Progress Tracker

> **Project**: BreakMate Multi-Pet AI Desktop Companion
> **Started**: 2026-05-21
> **Status**: In Progress

---

## Goal

Transform the existing single-cat BreakMate companion into a modular, scalable, multi-pet AI desktop companion framework using Flutter + Flame + macOS NSPanel **without rewriting working systems**.

---

## Completed Tasks ✅

### 1. Codebase Analysis & Architecture Mapping

- Mapped 12 core companion files
- Documented EventBus events, DI setup, Flame game structure
- Analyzed macOS window management (`CompanionWindowManager.swift`)
- Documented multi-engine setup (`companionMain()`, `overlayMain()`)

### 2. Domain Models Created

- `pet_type.dart` - `PetSpecies` enum (cat, dog, bird, rabbit, hamster, reptile), `PetVariant` class
- `pet_profile.dart` - Complete pet configuration with `const` constructor, `copyWith`, `toMap`/`fromMap`, presets (`orangeCat`, `goldenDog`)
- `pet_personality.dart` - 8 trait axes, `energetic`/`lazy` presets
- `pet_mood.dart` - 12 mood states (happy, playful, relaxed, curious, tired, hungry, affectionate, alert, scared, bored, satisfied, mischievous)
- `pet_behavior_context.dart` - Context-aware behavior tracking
- `pet_animation_state.dart` - 14 animation states (idle, walk, run, sleep, typing, excited, sad, breakMode, focusMode, angry, notification, celebrate, lick1, lick2)
- `pet_state_machine.dart` - Generic FSM with 31 states, 22 events, weighted transitions with `weight`, `minDuration`, `cooldown`, optional `condition`. Added `stateStream` getter, `_stateController`, `dart:async` import

### 3. Services Implemented

- `pet_behavior_brain.dart` - AI decision engine with weighted scoring, recency/frequency penalties, top-3 candidate selection
- `pet_registry_service.dart` - Pet registration, auto-selection, preset fallbacks
- `pet_navigation_service.dart` - Singleton navigation with cursor attraction, wandering, physics. Requires `initialize({required Size screenSize})`
- `pet_companion_service.dart` - High-level orchestrator extending `ChangeNotifier`. Exposes `stateMachine`, `navigation`, `handleEvent(PetEvent)`

### 4. Asset Structure Setup

- Created `assets/animations/pets/cat/orange_cat/` directory
- Created `assets/animations/pets/dog/goldie/` directory
- Copied sprite assets from legacy locations
- Created `pets.json` runtime manifest with profile definitions
- Updated `pubspec.yaml` with new asset registrations

### 5. Integration Fixes

- Updated `companion_game.dart` constructor: simplified `PetPersonality()`, removed `PetMood.happy`, used `PetProfile.orangeCat`
- Added `stateMachine`, `handleEvent(PetEvent)`, `navigation` getters to `pet_companion_service.dart`
- Updated `_mapAppEventToCatEvent` in `companion_game.dart`: removed undefined `BreakCompletedEvent`/`NotificationEvent` handling
- Fixed `screenSize` type mismatch: `Vector2` → `Size(size.x, size.y)`
- Added `run` constant to `CatAnimationState` enum
- Updated switch statement: `PetState.turning` → `CatAnimationState.run`
- Successfully initialized navigation: `_petService.initialize(screenSize: Size(size.x, size.y))`

---

## Currently In Progress 🔄

### Task: Generalize CatAssetLoader → PetAssetLoader

- **Status**: Analyzing existing `cat_asset_loader.dart` (402 lines)
- **Goal**: Create generic `PetAssetLoader` supporting:
  - Dynamic species/variant paths (`assets/animations/pets/{species}/{variant}/`)
  - Runtime `pets.json` parsing
  - Sprite sheet and separate file formats
  - Graceful fallback for missing animations
  - Image caching and temp PNG extraction for tray icons
- **Next**: Create `pet_asset_loader.dart` and migrate functionality

---

## Pending Tasks 📋

### Phase 1: Asset System (Current)

- [ ] Create `pet_asset_loader.dart` with generic species/variant support
- [ ] Implement runtime `pets.json` parsing and validation
- [ ] Add graceful fallback for missing animation states
- [ ] Update `pubspec.yaml` with complete asset structure

### Phase 2: Flame Integration

- [ ] Wire `PetCompanionService` into `CompanionComponent.update()` loop
- [ ] Replace hardcoded `CatTheme` references with `PetProfile`
- [ ] Update `CompanionComponent` to use `PetAssetLoader`
- [ ] Integrate frame-ticked state/physics updates

### Phase 3: macOS Window Enhancements

- [ ] Update `CompanionWindowManager.swift` for edge snapping
- [ ] Add momentum-based movement
- [ ] Improve multi-monitor handling
- [ ] Smart click-through toggle based on interaction state

### Phase 4: Testing & Verification

- [ ] Verify full compilation (`flutter analyze`)
- [ ] Test runtime behavior of navigation system
- [ ] Test AI decision engine transitions
- [ ] Validate CPU usage <2% idle
- [ ] Test multi-pet switching

---

## Modified Files

| File                                                         | Changes                                                         | Status  |
| ------------------------------------------------------------ | --------------------------------------------------------------- | ------- |
| `lib/features/companion/domain/pet_state_machine.dart`       | Added `stateStream`, `_stateController`, `dart:async` import    | ✅ Done |
| `lib/features/companion/flame/companion_game.dart`           | Constructor updated, `_mapAppEventToCatEvent`, `screenSize` fix | ✅ Done |
| `lib/features/companion/domain/cat_animation_state.dart`     | Added `run` constant                                            | ✅ Done |
| `lib/features/companion/services/pet_companion_service.dart` | Added `stateMachine`, `navigation`, `handleEvent`               | ✅ Done |
| `assets/animations/pets/pets.json`                           | Created runtime manifest                                        | ✅ Done |
| `pubspec.yaml`                                               | Added new asset paths                                           | ✅ Done |

---

## Key Decisions

1. **Architecture**: `features/companion/` with `domain/`, `services/`, `flame/`, `ai/`, `overlays/`, `interactions/`, `assets/`, `controllers/`, `widgets/`
2. **Abstraction**: Existing `CatStateMachine` → `PetStateMachine`, `CompanionBehaviorEngine` → `PetBehaviorEngine`
3. **Asset Loading**: Graceful fallback for missing animations, metadata-driven via `pets.json`
4. **Event System**: Retain `EventBus` pub/sub for loose coupling
5. **AI Brain**: Weighted random from top 3 candidates, recency/frequency penalties
6. **Service Pattern**: `PetCompanionService` as high-level orchestrator exposing `navigation` and `stateMachine`

---

## Next Immediate Action

Create `lib/features/companion/assets/pet_asset_loader.dart` to replace `cat_asset_loader.dart` with generic multi-pet support.

current exection status

```
Goal
- Transform the existing single-cat BreakMate companion into a modular, scalable, multi-pet AI desktop companion framework using Flutter + Flame + macOS NSPanel without rewriting working systems.
Constraints & Preferences
- Integrate with existing architecture (CompanionGame, EventBus, overlayMain(), companionMain(), CompanionWindowManager.swift, GetIt DI, multi-engine setup).
- Target <2% CPU idle usage; reuse low CPU Flame optimizations.
- Generalize cat-specific logic into a Pet Companion Framework under features/companion/.
- Implement dynamic domain models: PetType, PetProfile, PetPersonality, PetMood, PetBehaviorContext, etc.
- Asset structure: assets/animations/pets/{species}/{variant}/.
- Advanced FSM with weighted transitions, cooldowns, mood/personality awareness.
- AI decision engine (pet_behavior_brain.dart) for autonomous, non-repetitive behaviors.
- Multi-display roaming, organic navigation, advanced mouse/cursor interaction.
- Extend CompanionWindowManager.swift for edge snapping, momentum, smart click-through.
- DO NOT rewrite existing systems; extend, abstract, modularize.
- Maintain a .md progress tracker updated with every completed task.
Progress
Done
- Mapped 12 core companion files, EventBus events, DI setup, Flame game structure, macOS window management.
- Created domain models: pet_personality.dart, pet_animation_state.dart, pet_state_machine.dart, pet_type.dart, pet_profile.dart, pet_behavior_context.dart, pet_mood.dart.
- Implemented pet_behavior_brain.dart, pet_registry_service.dart, pet_navigation_service.dart, pet_companion_service.dart.
- Created assets/animations/pets/{cat, dog}/ dirs, copied sprites, created pets.json manifest, updated pubspec.yaml.
- Verified API signatures for companion_game.dart, pet_companion_service.dart, app_events.dart.
- Applied constructor edits to companion_game.dart: simplified PetPersonality(), removed PetMood.happy, used PetProfile.orangeCat.
- Updated pet_companion_service.dart: added stateMachine, handleEvent(PetEvent), navigation getters.
- Updated _mapAppEventToCatEvent in companion_game.dart: removed undefined BreakCompletedEvent/NotificationEvent handling.
- Added stateStream getter, _stateController, dart:async import to pet_state_machine.dart.
- Added run constant to CatAnimationState enum.
- Fixed screenSize type mismatch in companion_game.dart (Vector2 to Size).
- Successfully initialized navigation via _petService.initialize(screenSize: Size(size.x, size.y)).
- Created PET_COMPANION_PROGRESS.md tracker at project root.
- Created lib/features/companion/assets/pet_asset_loader.dart with ui.Image/SpriteAnimation caching, pets.json manifest parsing, temp PNG icon extraction, and dynamic sprite sheet/individual frame loading.
- Resolved LSP type errors in pet_asset_loader.dart by applying explicit .toDouble() and .toInt() casts to JSON-parsed numeric values for Vector2 positions and stepTime assignments.
- Verified flutter analyze lib/features/companion/ passes with only minor lint warnings/info.
- Fixed method name mismatch in pet_companion_service.dart: renamed triggerEvent to handleEvent to align with companion_game.dart calls.
- Inspected current companion_game.dart and companion_component.dart source code to verify state, verify FSM implementations (MouseFollowState, FreeWanderingState), and prepare for PetCompanionService integration.
In Progress
- Resolving PetCompanionService integration gaps: fixing missing initialize() arguments and wiring service state/position updates to CompanionComponent.
Blocked
- (none)
Key Decisions
- Architecture organized under features/companion/ with domain/, services/, flame/, ai/, overlays/, interactions/, assets/, controllers/, widgets/.
- Existing CatStateMachine and CompanionBehaviorEngine abstracted into generic PetStateMachine and PetBehaviorEngine wrappers.
- Asset loader handles missing animations gracefully, supports metadata-driven runtime registration via pets.json.
- Retain EventBus pub/sub and GetIt DI for loose coupling.
- AI brain uses weighted random selection from top 3 candidates, penalizing recency/frequency.
- PetRegistryService auto-selects first registered pet or falls back to presets.
- PetCompanionService acts as high-level orchestrator, exposing navigation and stateMachine for direct Flame integration.
- JSON manifest numeric values require explicit .toDouble()/.toInt() casting to satisfy Flame Vector2 and animation stepTime strict typing.
Next Steps
- Fix companion_game.dart:56 to pass screenSize to _petService.initialize().
- Implement state/position sync from PetCompanionService to CompanionComponent.
- Wire PetCompanionService into CompanionComponent's update() loop for frame-ticked state/physics updates.
- Update CompanionWindowManager.swift for improved macOS NSPanel physics, edge snapping, multi-monitor handling.
- Verify full compilation and runtime behavior of initialized navigation and AI decision systems.
- Update PET_COMPANION_PROGRESS.md upon task completion.
Critical Context
- companion_game.dart: Extends FlameGame, initializes PetCompanionService with PetProfile.orangeCat, PetStateMachine, PetBehaviorBrain, PetNavigationService. Constructor requires CatTheme initialTheme. _mapAppEventToCatEvent implemented. screenSize mismatch resolved. Subscribes to AppEvent and PetState streams. Calls _petService.handleEvent() (fixed). _petService.initialize() currently missing screenSize argument.
- pet_state_machine.dart: 31 PetState (incl. turning), 22 PetEvent, PetTransition with weight, minDuration, cooldown, optional condition. stateStream getter added, dart:async import resolved.
- cat_animation_state.dart: Enum with 14 states: idle, walk, run, sleep, typing, excited, sad, breakMode, focusMode, angry, notification, celebrate, lick1, lick2.
- companion_component.dart: Extends SpriteAnimationGroupComponent<CatAnimationState>, implements MouseFollowState & FreeWanderingState FSMs, tracks _velocity, _stateElapsed, _behaviorTimer, _isFollowingMouse, handles TapCallbacks/HoverCallbacks. Uses CatTheme for breed-specific physics.
- pet_navigation_service.dart: Singleton. initialize({required Size screenSize, Offset? startPosition}) required before use. Exposes update(double dt), updateConfig(), cursor attraction/physics.
- app_events.dart: Sealed AppEvent class. Events: TimerStateChangedEvent, BreakStartedEvent, BreakEndedEvent, BreakPostponedEvent, CompanionStateChangedEvent, CompanionInteractionEvent, CompanionPositionChangedEvent. CompanionState enum: idle, walking, sleeping, alert, dragging, listening, happy, breakReminder, meetingPaused, focusMode.
- PetCompanionService: Extends ChangeNotifier. Exposes stateMachine, navigation, handleEvent(PetEvent). Constructor requires stateMachine, brain, navigation, profile. Exposes profile, mood, context getters. Contains update(), dispose(), decision interval logic. triggerEvent renamed to handleEvent.
- pet_asset_loader.dart: New generic loader. Caches ui.Image and Map<CatAnimationState, SpriteAnimation>. Parses pets.json for sprite sheet metadata. Extracts icons to temp directory. Type casting errors resolved.
- PetProfile: const constructor requires id, name, species, variant. Optional: personality, initialMood, primaryColor, secondaryColor, baseScale, movementSpeed, isEnabled. Presets: orangeCat, goldenDog.
- PetPersonality: 8 trait axes, defaults, energetic/lazy presets.
- PetMood: happy, playful, relaxed, curious, tired, hungry, affectionate, alert, scared, bored, satisfied, mischievous.
- EventBus System: Central EventBusService pub/sub. Key events: BreakStartedEvent, MeetingDetectedEvent, FocusModeEvent, IdleDetectedEvent, ActivityResumedEvent, TrayActionEvent, TimerStateChangedEvent, CompanionStateEvent, CompanionThemeChangedEvent, CompanionToggleEvent.
- DI & Entry Points: GetIt registers core services. main.dart -> runApp(), companionMain(), overlayMain().
- Window Management: CompanionWindowController -> WindowService -> CompanionWindowManager.swift (NSPanel, click-through, drag, boundaries).
Relevant Files
- /Users/intersamrt/Documents/Flutter-Projects/standup/lib/features/companion/services/pet_companion_service.dart: High-level orchestrator extending ChangeNotifier. Manages mood, context, AI brain, state machine, and navigation. handleEvent fixed.
- /Users/intersamrt/Documents/Flutter-Projects/standup/lib/features/companion/flame/companion_component.dart: Flame sprite component with MouseFollowState & FreeWanderingState FSMs, velocity physics, tap/hover callbacks. Target for service integration.
- /Users/intersamrt/Documents/Flutter-Projects/standup/lib/features/companion/assets/pet_asset_loader.dart: New generic asset loader for pets. Handles caching, pets.json parsing, icon extraction, and SpriteAnimation creation.
- /Users/intersamrt/Documents/Flutter-Projects/standup/lib/features/companion/domain/pet_state_machine.dart: Generic FSM with 31 states, 22 events, weighted transitions.
- /Users/intersamrt/Documents/Flutter-Projects/standup/lib/features/companion/flame/companion_game.dart: Flame entry point. Initializes services, manages AppEvent/PetState subscriptions, and maps app events. Needs initialize arg fix.
- /Users/intersamrt/Documents/Flutter-Projects/standup/lib/features/companion/domain/cat_animation_state.dart: Animation enum with 14 states.
- /Users/intersamrt/Documents/Flutter-Projects/standup/lib/features/companion/services/pet_navigation_service.dart: Singleton navigation service requiring initialize({required Size screenSize}).
- /Users/intersamrt/Documents/Flutter-Projects/standup/lib/features/companion/ai/pet_behavior_brain.dart: AI decision engine with weighted scoring, recency/frequency penalties.
- /Users/intersamrt/Documents/Flutter-Projects/standup/lib/features/companion/data/cat_asset_loader.dart: Legacy cat-specific asset loader. Being replaced.
- /Users/intersamrt/Documents/Flutter-Projects/standup/lib/features/companion/domain/pet_profile.dart: Domain model for pet configuration. Presets: orangeCat, goldenDog.
- /Users/intersamrt/Documents/Flutter-Projects/standup/lib/core/events/app_events.dart: Sealed AppEvent class, CompanionState enum, core events.
- /Users/intersamrt/Documents/Flutter-Projects/standup/macos/Runner/CompanionWindowManager.swift: Native NSPanel controller for click-through, drag, boundaries.
- /Users/intersamrt/Documents/Flutter-Projects/standup/assets/animations/pets/pets.json: Runtime asset manifest defining profiles, variants, sprite metadata.
- /Users/intersamrt/Documents/Flutter-Projects/standup/pubspec.yaml: Updated asset registration.
- /Users/intersamrt/Documents/Flutter-Projects/standup/PET_COMPANION_PROGRESS.md: Progress tracker for completed, pending, and in-progress tasks.
```
