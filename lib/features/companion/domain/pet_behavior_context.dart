import 'dart:ui';
import 'pet_mood.dart';
import 'pet_profile.dart';

/// Contextual data used by the AI decision engine to determine pet behavior.
class PetBehaviorContext {
  final PetProfile profile;
  final PetMoodState currentMood;
  final DateTime lastStateChange;
  final Duration timeInCurrentState;
  final bool isUserInteracting;
  final bool isCursorNearby;
  final Offset cursorPosition;
  final Offset petPosition;
  final Size screenSize;
  final bool isBreakActive;
  final bool isMeetingDetected;
  final bool isFocusMode;
  final bool isIdle;
  final double ambientNoiseLevel;
  final int interactionCount;
  final DateTime? lastInteractionTime;

  // Stateful Needs (from 0.0 to 1.0)
  final double curiosity;
  final double fatigue;
  final double boredom;
  final Duration totalWorkToday;

  PetBehaviorContext({
    required this.profile,
    required this.currentMood,
    required this.lastStateChange,
    required this.timeInCurrentState,
    this.isUserInteracting = false,
    this.isCursorNearby = false,
    Offset? cursorPosition,
    Offset? petPosition,
    Size? screenSize,
    this.isBreakActive = false,
    this.isMeetingDetected = false,
    this.isFocusMode = false,
    this.isIdle = false,
    this.ambientNoiseLevel = 0.0,
    this.interactionCount = 0,
    this.lastInteractionTime,
    this.curiosity = 0.5,
    this.fatigue = 0.0,
    this.boredom = 0.0,
    this.totalWorkToday = Duration.zero,
  })  : cursorPosition = cursorPosition ?? Offset.zero,
        petPosition = petPosition ?? Offset.zero,
        screenSize = screenSize ?? Size.zero;

  PetBehaviorContext copyWith({
    PetProfile? profile,
    PetMoodState? currentMood,
    DateTime? lastStateChange,
    Duration? timeInCurrentState,
    bool? isUserInteracting,
    bool? isCursorNearby,
    Offset? cursorPosition,
    Offset? petPosition,
    Size? screenSize,
    bool? isBreakActive,
    bool? isMeetingDetected,
    bool? isFocusMode,
    bool? isIdle,
    double? ambientNoiseLevel,
    int? interactionCount,
    DateTime? lastInteractionTime,
    double? curiosity,
    double? fatigue,
    double? boredom,
    Duration? totalWorkToday,
  }) {
    return PetBehaviorContext(
      profile: profile ?? this.profile,
      currentMood: currentMood ?? this.currentMood,
      lastStateChange: lastStateChange ?? this.lastStateChange,
      timeInCurrentState: timeInCurrentState ?? this.timeInCurrentState,
      isUserInteracting: isUserInteracting ?? this.isUserInteracting,
      isCursorNearby: isCursorNearby ?? this.isCursorNearby,
      cursorPosition: cursorPosition ?? this.cursorPosition,
      petPosition: petPosition ?? this.petPosition,
      screenSize: screenSize ?? this.screenSize,
      isBreakActive: isBreakActive ?? this.isBreakActive,
      isMeetingDetected: isMeetingDetected ?? this.isMeetingDetected,
      isFocusMode: isFocusMode ?? this.isFocusMode,
      isIdle: isIdle ?? this.isIdle,
      ambientNoiseLevel: ambientNoiseLevel ?? this.ambientNoiseLevel,
      interactionCount: interactionCount ?? this.interactionCount,
      lastInteractionTime: lastInteractionTime ?? this.lastInteractionTime,
      curiosity: curiosity ?? this.curiosity,
      fatigue: fatigue ?? this.fatigue,
      boredom: boredom ?? this.boredom,
      totalWorkToday: totalWorkToday ?? this.totalWorkToday,
    );
  }

  bool get isNearScreenEdge {
    const edgeThreshold = 50.0;
    return petPosition.dx < edgeThreshold ||
        petPosition.dx > screenSize.width - edgeThreshold ||
        petPosition.dy < edgeThreshold ||
        petPosition.dy > screenSize.height - edgeThreshold;
  }

  double get cursorDistance {
    return (petPosition - cursorPosition).distance;
  }

  bool get isHighEnergyState {
    return profile.personality.activityLevel > 0.5 &&
        currentMood.intensity > 0.3;
  }

  bool get shouldSeekInteraction {
    return profile.personality.sociability > 0.6 &&
        !isUserInteracting &&
        (currentMood.mood == PetMood.affectionate ||
        currentMood.mood == PetMood.playful);
  }
}
