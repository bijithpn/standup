part of 'pet_state_machine.dart';

enum PetState {
  idle,
  blink,
  stretch,
  walk,
  run,
  sleep,
  alert,
  happy,
  angry,
  drag,
  breakReminder,
  meetingPaused,
  curious,
  excited,
  sad,
  grooming,
  playing,
  eating,
  celebrating,
  dancing,
  hiding,
  quiet,
  interacting,
  following,
  jumping,
  affectionate,
  turning,
  resting,
  bored,
  exploring,
  scared,
  breatheFire,
  fly,
  chasing,
  fetching,
  falling,
  reacting,
}

extension PetStateAvatarClip on PetState {
  AvatarAnimationClip toAnimationClip() {
    switch (this) {
      case PetState.idle:
        return AvatarAnimationClip.idle;
      case PetState.blink:
        return AvatarAnimationClip.blink;
      case PetState.stretch:
        return AvatarAnimationClip.stretch;
      case PetState.walk:
      case PetState.turning:
      case PetState.exploring:
        return AvatarAnimationClip.walk;
      case PetState.run:
      case PetState.chasing:
        return AvatarAnimationClip.run;
      case PetState.sleep:
      case PetState.resting:
        return AvatarAnimationClip.sleep;
      case PetState.alert:
        return AvatarAnimationClip.lookAround;
      case PetState.happy:
      case PetState.affectionate:
        return AvatarAnimationClip.happiness;
      case PetState.angry:
      case PetState.scared:
        return AvatarAnimationClip.anger;
      case PetState.celebrating:
        return AvatarAnimationClip.celebrate;
      case PetState.dancing:
        return AvatarAnimationClip.bounce;
      case PetState.jumping:
        return AvatarAnimationClip.jump;
      case PetState.curious:
      case PetState.interacting:
      case PetState.following:
        return AvatarAnimationClip.glance;
      case PetState.playing:
        return AvatarAnimationClip.wiggle;
      case PetState.eating:
        return AvatarAnimationClip.nod;
      case PetState.bored:
        return AvatarAnimationClip.stretch;
      default:
        return AvatarAnimationClip.idle;
    }
  }
}

enum PetEvent {
  tick,
  userClick,
  userDoubleClick,
  userHover,
  userDragStart,
  userDragEnd,
  breakStarted,
  breakEnded,
  meetingDetected,
  meetingEnded,
  idleTimeout,
  activityDetected,
  randomBehavior,
  cursorNearby,
  cursorLeft,
  notificationReceived,
  breakCompleted,
  petFed,
  petPlayed,
  animationComplete,
  cursorEnteredZone,
  cursorExitedZone,
  cursorDwell,
  cursorFastMove,
  throwableSpawned,
  throwableStationary,
  throwableFetched,
  throwableReturned,
  throwableEaten,
  landedOnSurface,
  windowOverlap,
  windowOverlapEnded,
  surfaceLost,
  loopBlocked,
}

class PetTransition {
  final PetEvent event;
  final PetState targetState;
  final double weight;
  final Duration? minDuration;
  final Duration? cooldown;
  final bool Function(PetMoodState? currentMood, PetPersonality personality)?
  condition;

  const PetTransition({
    required this.event,
    required this.targetState,
    this.weight = 1.0,
    this.minDuration,
    this.cooldown,
    this.condition,
  });
}

const Map<PetState, int> _statePriority = {
  PetState.falling: 5,
  PetState.chasing: 4,
  PetState.fetching: 4,
  PetState.run: 3,
  PetState.reacting: 3,
  PetState.walk: 2,
  PetState.resting: 2,
  PetState.idle: 1,
};
