// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
part of 'pet_behavior_engine.dart';

extension _PetBehaviorSimulation on PetBehaviorEngine {
  void _advance(double dt) {
    _sinceCursorSample += dt;
    _clock += Duration(microseconds: (dt * 1e6).round());
    final reach = math.max(_viewport.longestSide, 1.0);

    final tracking = _hasCursor && !_viewport.isEmpty && _gazeSettings.enabled;
    final toCursor = tracking ? _cursor - _eye : Offset.zero;
    final distance = toCursor.distance;

    _updatePointerProximity(tracking);
    _updateQuietPeriod();
    if (_machine.advance(_clock)) _emotion = _resolveEmotion();

    _updateAttention(dt, distance);
    _updateArousal(dt);
    _updateGazeTarget(dt, toCursor, reach, distance);
    _integrateGaze(dt);
    _integratePosture(dt);
    _updateBlink(dt);
    _updateImpulses(dt);
    _updateDrives(dt);

    if (_idleMotion) {
      _breathPhase += dt * _breathRate();
      if (_breathPhase > math.pi * 2) _breathPhase -= math.pi * 2;
    }
  }

  /// Tells the mood machine when the pointer enters or leaves the pet.
  ///
  /// The enter and exit areas differ in size so a pointer resting on the edge
  /// does not fire an event every frame.
  void _updatePointerProximity(bool tracking) {
    if (!tracking) {
      if (_pointerNear) {
        _pointerNear = false;
        _machine.post(CompanionEvent.pointerExited, _clock);
      }
      return;
    }
    final inside = _pointerNear
        ? _viewport.inflate(36).contains(_cursor)
        : _viewport.inflate(10).contains(_cursor);
    if (inside == _pointerNear) return;
    _pointerNear = inside;
    // Only a pointer that is actually moving is interesting. One that was
    // parked on the pet before it appeared should not make it start.
    if (inside && !_cursorIsStill) {
      _machine.post(CompanionEvent.pointerEntered, _clock);
    } else if (!inside) {
      _machine.post(CompanionEvent.pointerExited, _clock);
    }
  }

  void _updateQuietPeriod() {
    final quiet = _quietSeconds > PetBehaviorEngine._drowsyAfter;
    if (quiet == _quietAnnounced) return;
    _quietAnnounced = quiet;
    _machine.post(
      quiet
          ? CompanionEvent.quietPeriodStarted
          : CompanionEvent.quietPeriodEnded,
      _clock,
    );
  }

  /// Whether the cursor should be treated as holding still right now.
  bool get _cursorIsStill =>
      _cursorResting ||
      _sinceCursorSample > PetBehaviorEngine._staleSampleSeconds;

  void _updateAttention(double dt, double distance) {
    if (_viewport.isEmpty || !_hasCursor || !_gazeSettings.enabled) {
      _attention = PetBehaviorEngine._decay(_attention, 0.5, dt);
      _quietSeconds += dt;
      return;
    }

    // Interest falls off with distance and rises with motion.
    final proximity = distance >= _interestRadius
        ? 0.0
        : 1.0 - (distance / _interestRadius);
    final motion = math.min(1.0, _cursorSpeed / 900.0);

    if (_cursorIsStill) {
      _quietSeconds += dt;
      // Staring at something that has stopped moving gets boring. Interest
      // bleeds away faster than it built, which is what makes the pet look
      // away on its own instead of locking on forever.
      _attention = PetBehaviorEngine._decay(
        _attention,
        0.55 + proximity * 0.2,
        dt,
      );
    } else {
      final pull = proximity * (0.35 + motion * 0.9);
      _attention = math.min(1.0, _attention + pull * dt * 3.2);
    }

    if (distance < PetBehaviorEngine._intimateRadius && !_cursorIsStill) {
      _attention = math.max(_attention, 0.9);
    }
  }

  void _updateArousal(double dt) {
    final resting = _quietSeconds > PetBehaviorEngine._sleepAfter
        ? 0.04
        : _quietSeconds > PetBehaviorEngine._drowsyAfter
        ? 0.14
        : 0.3;
    final target = math.max(
      resting,
      math.max(
        _attention * 0.75,
        math.max(_startle, math.max(_delight, _playing)),
      ),
    );
    // Arousal climbs quickly and settles slowly, like a real startle response.
    final rate = target > _arousal ? 6.0 : 0.55;
    _arousal += (target - _arousal) * math.min(1.0, rate * dt);
  }

  void _updateGazeTarget(
    double dt,
    Offset toCursor,
    double reach,
    double distance,
  ) {
    if (_quietSeconds > PetBehaviorEngine._sleepAfter ||
        _machine.mood == CompanionMood.resting) {
      _setGazeTarget(Offset.zero, snap: false);
      return;
    }

    if (_attention > 0.28 &&
        _hasCursor &&
        !_viewport.isEmpty &&
        _gazeSettings.enabled) {
      final sector = _sectors.update(toCursor);
      if (sector == GazeDirection.center) {
        // Inside the dead zone the pointer is "right here". Looking straight
        // ahead reads as relaxed; chasing it around a few pixels does not.
        _setGazeTarget(Offset.zero, snap: false);
      } else {
        // Direction is snapped to the sector so the head does not jitter on a
        // boundary; how far the eyes travel still follows the distance.
        final dead = _gazeSettings.deadZone;
        final span = math.max(reach * 1.25 - dead, 1.0);
        final pull = ((distance - dead) / span).clamp(0.0, 1.0);
        var strength = 0.35 + 0.65 * pull;

        // Close up, the pet looks *at* the cursor rather than toward it.
        if (distance < PetBehaviorEngine._intimateRadius) {
          strength = math.min(1.0, strength * 1.2);
        }

        _setGazeTarget(sector.unit * strength, snap: false);
      }
      _idleGazeTimer = 0.9 + _random.nextDouble() * 1.4;
      return;
    }

    // Disengaged. A pointer that has gone quiet is no longer worth following.
    _sectors.reset();
    if (!_idleMotion) {
      _setGazeTarget(Offset.zero, snap: false);
      return;
    }

    // Look around on its own schedule.
    _idleGazeTimer -= dt;
    if (_idleGazeTimer <= 0) {
      _idleGazeTimer = 1.4 + _random.nextDouble() * 3.0;
      final drowsy = _quietSeconds > PetBehaviorEngine._drowsyAfter;
      final spread = drowsy ? 0.25 : 0.62;
      _setGazeTarget(
        Offset(
          (_random.nextDouble() * 2 - 1) * spread,
          (_random.nextDouble() * 2 - 1) * spread * 0.55 +
              (drowsy ? 0.25 : 0.0),
        ),
        snap: false,
      );
    }
  }

  void _setGazeTarget(Offset target, {required bool snap}) {
    if (snap) {
      _gaze = target;
      _gazeTarget = target;
      _saccadeT = 1.0;
      return;
    }

    final error = (target - _gazeTarget).distance;
    _gazeTarget = target;

    // Big jumps are made with a saccade; small corrections are tracked
    // smoothly. Doing both is what separates a living eye from a lerp.
    if (error > PetBehaviorEngine._saccadeThreshold &&
        _saccadeT >= 1.0 &&
        !_reducedMotion) {
      _saccadeFrom = _gaze;
      _saccadeT = 0.0;
      // Eyes and lids are wired together — a large saccade often carries a
      // blink with it.
      if (_random.nextDouble() < 0.28 && _blinkProgress < 0) {
        _blinkProgress = 0.0;
      }
    }
  }

  void _integrateGaze(double dt) {
    if (_saccadeT < 1.0) {
      _saccadeT = math.min(
        1.0,
        _saccadeT + dt / PetBehaviorEngine._saccadeDuration,
      );
      // Ease-out: a saccade leaves fast and arrives gently.
      final t = 1 - math.pow(1 - _saccadeT, 3).toDouble();
      _gaze = Offset(
        _saccadeFrom.dx + (_gazeTarget.dx - _saccadeFrom.dx) * t,
        _saccadeFrom.dy + (_gazeTarget.dy - _saccadeFrom.dy) * t,
      );
      return;
    }

    // Smooth pursuit, with gain rising as the pet pays more attention.
    final gain = 3.0 + _attention * 7.0;
    final k = math.min(1.0, gain * dt);
    _gaze = Offset(
      _gaze.dx + (_gazeTarget.dx - _gaze.dx) * k,
      _gaze.dy + (_gazeTarget.dy - _gaze.dy) * k,
    );
  }

  void _integratePosture(double dt) {
    // The head chases the eyes, the body chases the head, each softer than the
    // last. That ordering is the whole trick behind the motion reading as one
    // creature rather than three sliding parts.
    final headTarget = _gaze * (0.55 + _attention * 0.3);
    final headResult = PetBehaviorEngine._spring(
      _head,
      _headVelocity,
      headTarget,
      stiffness: 95.0,
      damping: 15.5,
      dt: dt,
    );
    _head = headResult.$1;
    _headVelocity = headResult.$2;

    final bodyTarget = _head * (0.3 + _arousal * 0.15);
    final bodyResult = PetBehaviorEngine._spring(
      _body,
      _bodyVelocity,
      bodyTarget,
      stiffness: 38.0,
      damping: 11.0,
      dt: dt,
    );
    _body = bodyResult.$1;
    _bodyVelocity = bodyResult.$2;

    // A curious head cocks to one side. Tie it to how far the pet is reaching
    // sideways, plus a little of its own drift.
    final drift = _idleMotion ? 1.0 : 0.0;
    final tiltTarget = _attention > 0.5
        ? _head.dx * 0.16 + math.sin(_breathPhase * 0.37) * 0.02 * drift
        : math.sin(_breathPhase * 0.31) * 0.03 * drift;
    _tilt += (tiltTarget - _tilt) * math.min(1.0, 3.0 * dt);
  }

  void _updateBlink(double dt) {
    if (_machine.mood == CompanionMood.resting) {
      _blink = 0.0;
      _blinkProgress = -1.0;
      return;
    }
    if (_quietSeconds > PetBehaviorEngine._sleepAfter) {
      _blink += (1.0 - _blink) * math.min(1.0, 2.5 * dt);
      return;
    }
    if (_quietSeconds > PetBehaviorEngine._drowsyAfter) {
      // Heavy lids, but still blinking occasionally.
      final droop = 0.45;
      if (_blinkProgress < 0) {
        _blink += (droop - _blink) * math.min(1.0, 2.0 * dt);
      }
    }

    if (_blinkProgress >= 0) {
      _blinkProgress += dt;
      const close = 0.045;
      const hold = 0.03;
      const open = 0.085;
      const total = close + hold + open;

      double value;
      if (_blinkProgress < close) {
        value = _blinkProgress / close;
      } else if (_blinkProgress < close + hold) {
        value = 1.0;
      } else if (_blinkProgress < total) {
        value = 1.0 - (_blinkProgress - close - hold) / open;
      } else {
        value = 0.0;
        _blinkProgress = -1.0;
        _blinkTimer = _nextBlinkDelay();
      }
      _blink = math.max(_blink, value.clamp(0.0, 1.0));
      if (_blinkProgress < 0) {
        _blink = _quietSeconds > PetBehaviorEngine._drowsyAfter ? 0.45 : 0.0;
      }
      return;
    }

    // With idle animation off the lids stay still unless an event asks.
    if (!_idleMotion) return;
    _blinkTimer -= dt;
    if (_blinkTimer <= 0) _blinkProgress = 0.0;
  }

  /// Blink spacing is irregular in life, so draw it from an exponential
  /// distribution rather than a fixed interval, with a floor so two blinks
  /// never run together.
  double _nextBlinkDelay() {
    final u = 1.0 - _random.nextDouble();
    final mean = _arousal > 0.7 ? 2.6 : 4.2;
    return 1.1 + -math.log(u) * mean;
  }

  void _updateImpulses(double dt) {
    _updateWobble(dt);
    _updateIdleAction(dt);
    _startle = PetBehaviorEngine._decay(_startle, _held ? 0.0 : 2.4, dt);
    _delight = PetBehaviorEngine._decay(_delight, 1.6, dt);
    // Much slower than the others: a game lasts, where a touch is over as
    // soon as the hand lifts. This rate keeps the pet visibly excited for
    // about forty seconds after a game and calm again within two minutes.
    _playing = PetBehaviorEngine._decay(_playing, 0.04, dt);

    // The walk cycle runs faster the harder the pet is travelling, and stops
    // dead when it is not.
    _travelPhase += dt * (5.5 + 7.0 * _travel.distance);

    if (_reducedMotion || !_animations) {
      _bounce = 0.0;
      _bounceVelocity = 0.0;
      return;
    }

    // A spring back to rest, so a pet lands and settles instead of snapping.
    const stiffness = 210.0;
    const damping = 14.0;
    _bounceVelocity += (-stiffness * _bounce - damping * _bounceVelocity) * dt;
    _bounce += _bounceVelocity * dt;
    if (_bounce.abs() < 0.05 && _bounceVelocity.abs() < 0.5) {
      _bounce = 0.0;
      _bounceVelocity = 0.0;
    }
  }

  void _updateWobble(double dt) {
    if (!_motionAllowed) {
      _wobble = 0.0;
      _wobbleVelocity = 0.0;
      return;
    }
    // A held pet dangles and swings; otherwise a lightly damped spring rings
    // the roll out over about a second.
    final target = _held ? math.sin(_clock.inMilliseconds / 260.0) * 0.12 : 0.0;
    _wobbleVelocity +=
        ((target - _wobble) * 120.0 - _wobbleVelocity * 5.5) * dt;
    _wobble += _wobbleVelocity * dt;
    if ((_wobble - target).abs() < 0.0008 && _wobbleVelocity.abs() < 0.01) {
      _wobble = target;
      _wobbleVelocity = 0.0;
    }
  }

  /// Now and then, with nobody touching it, the pet does something of its own:
  /// a small hop, a shake of the head, a stretch. This is what separates a
  /// living thing sitting there from a picture that breathes.
  void _updateIdleAction(double dt) {
    if (!_idleMotion || _held) return;
    if (_quietSeconds > PetBehaviorEngine._drowsyAfter) {
      return; // Dozing pets do not fidget.
    }
    _idleActionTimer -= dt;
    if (_idleActionTimer > 0) return;
    _idleActionTimer = 7.0 + _random.nextDouble() * 12.0;

    switch (_random.nextInt(4)) {
      case 0:
        _bounceVelocity = -70.0;
        _rock(2.5);
      case 1:
        _rock(6.0); // A quick shake of the head.
      case 2:
        _bounceVelocity = 40.0; // A stretch: sinks, then rises.
        _attention = math.max(_attention, 0.5);
      default:
        _rock(3.0);
        _idleGazeTimer = 0.0; // Looks somewhere else.
    }
  }

  /// Advances the slow feelings: affection fades, loneliness grows while
  /// ignored, weariness grows while working without a break.
  void _updateDrives(double dt) {
    _sinceInteraction += dt;
    _sinceBreak += dt;

    // Affection fades over roughly half an hour untended, so the warm face is
    // earned rather than permanent.
    _affection = math.max(0.0, _affection - dt / 1800);

    if (_sinceInteraction > PetBehaviorEngine._lonelyAfter) {
      _loneliness = math.min(
        1.0,
        _loneliness + dt / PetBehaviorEngine._lonelyAfter,
      );
    } else {
      _loneliness = math.max(0.0, _loneliness - dt / 600);
    }

    // Weariness only accrues while the user is actually at the machine; a
    // laptop asleep overnight should not tire the pet out.
    if (!_cursorIsStill && _sinceBreak > PetBehaviorEngine._wearyAfter) {
      _fatigue = math.min(1.0, _fatigue + dt / PetBehaviorEngine._wearyAfter);
    } else if (_cursorIsStill) {
      _fatigue = math.max(0.0, _fatigue - dt / 3600);
    }

    _emotion = _resolveEmotion();
  }

  /// Picks the single feeling the face should wear.
  ///
  /// Ordered by urgency rather than magnitude: a fright interrupts everything,
  /// and sleep beats any feeling the pet had before it dropped off. Only one
  /// emotion shows at a time, because a face blending three of them reads as
  /// none of them.
  PetEmotionState _resolveEmotion() {
    PetEmotionState state(PetEmotion emotion, double intensity) =>
        PetEmotionState(
          emotion: emotion,
          intensity: intensity.clamp(0.0, 1.0),
          affection: _affection,
          loneliness: _loneliness,
          fatigue: _fatigue,
        );

    // The mood machine owns every event-driven feeling. The ladder below only
    // fills in the slow, drive-based baseline when no reaction is showing.
    final mood = _machine.mood;
    if (mood == CompanionMood.resting) {
      return state(mood.emotion, mood.intensity);
    }
    if (mood == CompanionMood.surprised) {
      return state(PetEmotion.startled, math.max(_startle, mood.intensity));
    }
    // A game outranks everything except a fright, and outlasts it too.
    if (_playing > 0.2) {
      return state(PetEmotion.playful, 0.55 + _playing * 0.45);
    }
    // Rapid attention winds the pet up past mere contentment: it laughs.
    if (_delight > 0.25 && _arousal > 0.78) {
      return state(PetEmotion.laughing, 0.7 + _delight * 0.3);
    }
    if (mood == CompanionMood.happy ||
        mood == CompanionMood.encouraging ||
        mood == CompanionMood.attentive) {
      return state(mood.emotion, mood.intensity);
    }
    if (_quietSeconds > PetBehaviorEngine._sleepAfter) {
      return state(PetEmotion.sleepy, 1.0);
    }
    if (_delight > 0.25) {
      return state(PetEmotion.affectionate, 0.6 + _delight * 0.4);
    }
    if (_quietSeconds > PetBehaviorEngine._drowsyAfter) {
      return state(PetEmotion.sleepy, 0.55);
    }
    if (_fatigue > 0.45) return state(PetEmotion.weary, _fatigue);
    if (_loneliness > 0.4) return state(PetEmotion.lonely, _loneliness);
    if (_attention > 0.75 && _arousal > 0.7) {
      return state(PetEmotion.excited, _arousal);
    }
    if (_affection > 0.35) {
      return state(PetEmotion.happy, 0.45 + _affection * 0.55);
    }
    if (mood == CompanionMood.curious) {
      return state(PetEmotion.curious, math.max(_attention, mood.intensity));
    }
    if (_attention > 0.45) return state(PetEmotion.curious, _attention);
    return state(PetEmotion.content, 0.35 + _affection * 0.3);
  }

  double _breathRate() {
    if (_quietSeconds > PetBehaviorEngine._sleepAfter) return 1.05;
    if (_quietSeconds > PetBehaviorEngine._drowsyAfter) return 1.5;
    return 2.0 + _arousal * 2.6;
  }

  PetActivity _activity() {
    if (_quietSeconds > PetBehaviorEngine._sleepAfter) {
      return PetActivity.sleeping;
    }
    if (_delight > 0.25) return PetActivity.delighted;
    if (_startle > 0.25) return PetActivity.startled;
    if (_playing > 0.2) return PetActivity.playful;
    if (_quietSeconds > PetBehaviorEngine._drowsyAfter) {
      return PetActivity.drowsy;
    }
    if (_attention > 0.75 && _arousal > 0.72) return PetActivity.playful;
    if (_attention > 0.5) return PetActivity.watching;
    if (_attention > 0.22) return PetActivity.curious;
    return PetActivity.idle;
  }

  void _publish() {
    final breath = math.sin(_breathPhase);
    final startleRecoil = _motionAllowed ? _startle * 8.0 : 0.0;
    final delightLift = _motionAllowed ? _delight * 6.0 : 0.0;

    // Travel rides on top of the cursor-driven posture rather than replacing
    // it, so a pet crossing the screen can still glance at where the pointer
    // went. The bob is what sells it as steps rather than a slide.
    final travelVigour = _travel.distance;
    final trot = travelVigour == 0
        ? 0.0
        : math.sin(_travelPhase) * 3.4 * travelVigour;

    final previous = _snapshot;
    _snapshot = PetBehaviorSnapshot(
      gaze: _gaze,
      headTurn: _head,
      bodyLean: Offset(
        (_body.dx + _travel.dx * 0.55).clamp(-1.0, 1.0),
        (_body.dy + _travel.dy * 0.3).clamp(-1.0, 1.0),
      ),
      blink: _blink.clamp(0.0, 1.0),
      breath: breath,
      bounce: _bounce - delightLift + startleRecoil - trot.abs(),
      squash: !_motionAllowed
          ? 1.0
          : 1.0 +
                (_idleMotion ? breath * 0.012 : 0.0) +
                _delight * 0.05 -
                _startle * 0.03 +
                // Squash and stretch: narrower and taller in the air, wider
                // and shorter as it lands. This is most of what makes a hop
                // read as a body rather than a sticker moving up and down.
                (_bounce * 0.0045).clamp(-0.14, 0.16),
      tilt: _tilt + _travel.dx * 0.11 + _wobble,
      arousal: _arousal.clamp(0.0, 1.0),
      attention: _attention.clamp(0.0, 1.0),
      activity: _activity(),
      emotion: _emotion,
      gazeDirection: _sectors.direction,
      mood: _machine.mood,
    );
    // A pet that has settled produces identical frames. Telling listeners
    // anyway would rebuild and repaint the avatar for nothing.
    if (PetBehaviorEngine._visiblySame(previous, _snapshot)) return;
    notifyListeners();
  }
}
