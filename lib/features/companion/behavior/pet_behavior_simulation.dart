part of 'pet_behavior_engine.dart';

/// Per-step simulation of the engine (part of pet_behavior_engine.dart); _advance runs these updates in a fixed order each tick.
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
    _layers.update(
      dt,
      asleep: _asleep,
      emotion: _emotion.emotion != PetEmotion.content,
      activity: _attention > 0.22,
      interaction:
          _held ||
          _delight > 0.25 ||
          _startle > 0.25 ||
          _playing > 0.2 ||
          _dizzy > 0.05,
    );

    _updateAttention(dt, distance);
    _updateArousal(dt);
    _updateGazeTarget(dt, toCursor, reach, distance);
    _integrateGaze(dt);
    _integratePosture(dt);
    _updateDizzy(dt);
    _updateBlink(dt);
    _updateImpulses(dt);
    _updateLife(dt);
    _updateExpression(dt);
    _updateDrives(dt);

    if (_idleMotion) {
      _breathPhase += dt * _breathRate() * _p.breathRate;
      if (_breathPhase > math.pi * 2) _breathPhase -= math.pi * 2;
    }
  }

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

  bool get _cursorIsStill =>
      _cursorResting ||
      _sinceCursorSample > PetBehaviorEngine._staleSampleSeconds;

  void _updateAttention(double dt, double distance) {
    if (_viewport.isEmpty || !_hasCursor || !_gazeSettings.enabled) {
      _attention = PetBehaviorEngine._decay(_attention, 0.5, dt);
      _quietSeconds += dt;
      return;
    }

    final proximity = distance >= _interestRadius
        ? 0.0
        : 1.0 - (distance / _interestRadius);
    final motion = math.min(1.0, _cursorSpeed / 900.0);

    if (_cursorIsStill) {
      _quietSeconds += dt;

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
        _setGazeTarget(Offset.zero, snap: false);
      } else {
        final dead = _gazeSettings.deadZone;
        final span = math.max(reach * 1.25 - dead, 1.0);
        final pull = ((distance - dead) / span).clamp(0.0, 1.0);
        var strength = 0.35 + 0.65 * pull;

        if (distance < PetBehaviorEngine._intimateRadius) {
          strength = math.min(1.0, strength * 1.2);
        }

        _setGazeTarget(sector.unit * strength, snap: false);
      }
      _idleGazeTimer = 0.9 + _random.nextDouble() * 1.4;
      return;
    }

    _sectors.reset();
    if (!_idleMotion) {
      _setGazeTarget(Offset.zero, snap: false);
      return;
    }

    _idleGazeTimer -= dt;
    if (_idleGazeTimer <= 0) {
      _idleGazeTimer =
          (1.4 + _random.nextDouble() * 3.0) / (_p.glance * _p.speed);
      final drowsy = _quietSeconds > PetBehaviorEngine._drowsyAfter;
      final spread = drowsy ? 0.25 : 0.62 * _p.amplitude * _intensity;
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

    if (error > PetBehaviorEngine._saccadeThreshold &&
        _saccadeT >= 1.0 &&
        !_reducedMotion) {
      _saccadeFrom = _gaze;
      _saccadeT = 0.0;

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

      final t = 1 - math.pow(1 - _saccadeT, 3).toDouble();
      _gaze = Offset(
        _saccadeFrom.dx + (_gazeTarget.dx - _saccadeFrom.dx) * t,
        _saccadeFrom.dy + (_gazeTarget.dy - _saccadeFrom.dy) * t,
      );
      return;
    }

    final gain = 3.0 + _attention * 7.0;
    final k = math.min(1.0, gain * dt);
    _gaze = Offset(
      _gaze.dx + (_gazeTarget.dx - _gaze.dx) * k,
      _gaze.dy + (_gazeTarget.dy - _gaze.dy) * k,
    );
  }

  void _integratePosture(double dt) {
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

    final drift = _idleMotion ? 1.0 : 0.0;
    var tiltTarget = _attention > 0.5
        ? _head.dx * 0.16 + math.sin(_breathPhase * 0.37) * 0.02 * drift
        : math.sin(_breathPhase * 0.31) * 0.03 * drift;
    tiltTarget += _tiltGoal;
    _tilt += (tiltTarget - _tilt) * math.min(1.0, 3.0 * dt);
  }

  void _updateDizzy(double dt) {
    if (_held) _heldSeconds += dt;
    if (_dizzy <= 0) return;

    _dizzy = math.max(0.0, _dizzy - dt / PetBehaviorEngine._dizzySeconds);
    // Phase slows and amplitude eases out together so the wobble settles instead of cutting off.
    _dizzyPhase += dt * 6.5 * (0.35 + 0.65 * _dizzy);
    final fade = _dizzy * (2.0 - _dizzy);
    final orbit = Offset(math.cos(_dizzyPhase), math.sin(_dizzyPhase));
    final k = math.min(1.0, 10.0 * dt);

    final gaze = orbit * (0.7 * fade);
    final head = Offset(orbit.dx, orbit.dy * 0.6) * (0.5 * fade);
    _gaze = Offset(
      _gaze.dx + (gaze.dx - _gaze.dx) * k,
      _gaze.dy + (gaze.dy - _gaze.dy) * k,
    );
    _head = Offset(
      _head.dx + (head.dx - _head.dx) * k,
      _head.dy + (head.dy - _head.dy) * k,
    );
    _tilt = math.sin(_dizzyPhase * 0.5) * 0.2 * fade;
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
      final droop = 0.45;
      if (_blinkProgress < 0) {
        _blink += (droop - _blink) * math.min(1.0, 2.0 * dt);
      }
    }

    if (_blinkProgress >= 0) {
      _blinkProgress += dt * _p.speed;
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
        _secondBlink = !_secondBlink && _random.nextDouble() < _p.doubleBlink;
        _blinkTimer = _secondBlink ? 0.14 : _nextBlinkDelay();
      }
      _blink = math.max(_blink, value.clamp(0.0, 1.0));
      if (_blinkProgress < 0) {
        _blink = _quietSeconds > PetBehaviorEngine._drowsyAfter ? 0.45 : 0.0;
      }
      return;
    }

    if (!_idleMotion) return;
    _blinkTimer -= dt;
    if (_blinkTimer <= 0) _blinkProgress = 0.0;
  }

  double _nextBlinkDelay() {
    final skewed = math.pow(_random.nextDouble(), 1.3);
    final delay = _p.blinkMin + (_p.blinkMax - _p.blinkMin) * skewed;
    return _arousal > 0.7 ? delay * 0.75 : delay;
  }

  void _updateImpulses(double dt) {
    _updateWobble(dt);
    _updateIdleAction(dt);
    _startle = PetBehaviorEngine._decay(_startle, _held ? 0.0 : 2.4, dt);
    _delight = PetBehaviorEngine._decay(_delight, 1.6, dt);

    _playing = PetBehaviorEngine._decay(_playing, 0.04, dt);

    _travelPhase += dt * (5.5 + 7.0 * _travel.distance);

    if (_reducedMotion || !_animations) {
      _bounce = 0.0;
      _bounceVelocity = 0.0;
      return;
    }

    const stiffness = 180.0;
    const damping = 20.0;
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

    final target = _held ? math.sin(_clock.inMilliseconds / 260.0) * 0.12 : 0.0;
    _wobbleVelocity +=
        ((target - _wobble) * 100.0 - _wobbleVelocity * 14.0) * dt;
    _wobble += _wobbleVelocity * dt;
    if ((_wobble - target).abs() < 0.0008 && _wobbleVelocity.abs() < 0.01) {
      _wobble = target;
      _wobbleVelocity = 0.0;
    }
  }

  void _updateIdleAction(double dt) {
    if (!_idleMotion || _held || idleWeight < 0.6) return;
    _idleActionTimer -= dt;
    if (_idleActionTimer > 0) return;
    final pace = (0.4 + _p.energy * 1.2) * _p.speed;
    _idleActionTimer = (7.0 + _random.nextDouble() * 12.0) / pace;

    final k = _p.bounce * _p.amplitude * _intensity;
    switch (_random.nextInt(4)) {
      case 0:
        _bounceVelocity = -70.0 * k;
        _rock(2.5 * k);
      case 1:
        _rock(6.0 * k);
      case 2:
        _bounceVelocity = 40.0 * k;
        _attention = math.max(_attention, 0.5);
      default:
        _rock(3.0 * k);
        _idleGazeTimer = 0.0;
    }
  }

  bool get _asleep =>
      _quietSeconds > PetBehaviorEngine._drowsyAfter ||
      _machine.mood == CompanionMood.resting;

  bool get _bobbing => _p.bob > 0 && _idleMotion && idleWeight > 0.05;

  /// Ear/nose twitches, head tilts and bobbing; all scaled by the idle layer so they stop while asleep or interacting.
  void _updateLife(double dt) {
    final life = _idleMotion && !_held ? idleWeight * _intensity : 0.0;
    _earKick = PetBehaviorEngine._decay(_earKick, 5.0, dt);
    _noseKick = PetBehaviorEngine._decay(_noseKick, 4.0, dt);

    if (life < 0.3) {
      _tiltHold = 0.0;
      _tiltGoal = 0.0;
    } else {
      if (_random.nextDouble() < _p.earTwitch * dt) _earKick = 1.0;
      if (_random.nextDouble() < _p.noseTwitch * dt) _noseKick = 1.0;
      if (_tiltHold <= 0 && _random.nextDouble() < _p.headTilt * dt) {
        _tiltHold = 1.5 + _random.nextDouble() * 2.0;
        _tiltGoal =
            (_random.nextBool() ? 1.0 : -1.0) * 0.1 * _p.amplitude * _intensity;
      } else if (_tiltHold > 0) {
        _tiltHold -= dt;
        if (_tiltHold <= 0) _tiltGoal = 0.0;
      }
    }
    if (_bobbing) _bobPhase += dt * 4.2 * _p.speed;
  }

  (double, double, double, double) get _expressionTarget {
    final i = _emotion.intensity;
    final (brow, cheek, ear, beak) = switch (_emotion.emotion) {
      PetEmotion.content => (0.0, 0.1, 0.0, 0.0),
      PetEmotion.happy => (0.15, 0.7, 0.2, 0.0),
      PetEmotion.excited => (0.4, 0.5, 0.7, 0.25),
      PetEmotion.curious => (0.45, 0.0, 0.8, 0.0),
      PetEmotion.affectionate => (0.1, 0.8, 0.1, 0.0),
      PetEmotion.lonely => (-0.5, 0.0, -0.6, 0.0),
      PetEmotion.weary => (-0.3, 0.0, -0.5, 0.0),
      PetEmotion.sleepy => (-0.2, 0.0, -0.4, 0.0),
      PetEmotion.startled => (1.0, 0.0, 1.0, 0.35),
      PetEmotion.playful => (0.3, 0.6, 0.5, 0.3),
      PetEmotion.laughing => (0.2, 1.0, 0.3, 0.6),
      PetEmotion.dizzy => (-0.1, 0.0, -0.3, 0.15),
    };
    return (brow * i, cheek * i, ear * i, beak * i);
  }

  void _updateExpression(double dt) {
    final (brow, cheek, ear, beak) = _expressionTarget;
    final k = math.min(1.0, 4.0 * dt);
    _browRaise += (brow - _browRaise) * k;
    _cheekLift += (cheek - _cheekLift) * k;
    _earBase += (ear - _earBase) * k;
    _beakOpen += (beak - _beakOpen) * k;
  }

  bool get _lifeSettled {
    if (_earKick != 0.0 || _noseKick != 0.0 || _tiltHold > 0 || _bobbing) {
      return false;
    }
    final (brow, cheek, ear, beak) = _expressionTarget;
    const eps = 0.004;
    return (brow - _browRaise).abs() < eps &&
        (cheek - _cheekLift).abs() < eps &&
        (ear - _earBase).abs() < eps &&
        (beak - _beakOpen).abs() < eps;
  }

  /// Slow emotional drives (affection, loneliness, weariness since last break) that feed emotion resolution.
  void _updateDrives(double dt) {
    _sinceInteraction += dt;
    _sinceBreak += dt;

    _affection = math.max(0.0, _affection - dt / 1800);

    if (_sinceInteraction > PetBehaviorEngine._lonelyAfter) {
      _loneliness = math.min(
        1.0,
        _loneliness + dt / PetBehaviorEngine._lonelyAfter,
      );
    } else {
      _loneliness = math.max(0.0, _loneliness - dt / 600);
    }

    if (!_cursorIsStill && _sinceBreak > PetBehaviorEngine._wearyAfter) {
      _fatigue = math.min(1.0, _fatigue + dt / PetBehaviorEngine._wearyAfter);
    } else if (_cursorIsStill) {
      _fatigue = math.max(0.0, _fatigue - dt / 3600);
    }

    _emotion = _resolveEmotion();
  }

  PetEmotionState _resolveEmotion() {
    PetEmotionState state(PetEmotion emotion, double intensity) =>
        PetEmotionState(
          emotion: emotion,
          intensity: intensity.clamp(0.0, 1.0),
          affection: _affection,
          loneliness: _loneliness,
          fatigue: _fatigue,
        );

    if (_dizzy > 0.05) return state(PetEmotion.dizzy, 0.5 + _dizzy * 0.5);

    final mood = _machine.mood;
    if (mood == CompanionMood.resting) {
      return state(mood.emotion, mood.intensity);
    }
    if (mood == CompanionMood.surprised) {
      return state(PetEmotion.startled, math.max(_startle, mood.intensity));
    }

    if (_playing > 0.2) {
      return state(PetEmotion.playful, 0.55 + _playing * 0.45);
    }

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
    if (_dizzy > 0.05) return PetActivity.dizzy;
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

  /// Builds the immutable snapshot for the UI and notifies only if visibly different.
  void _publish() {
    final breath = math.sin(_breathPhase);
    final startleRecoil = _motionAllowed ? _startle * 8.0 : 0.0;
    final delightLift = _motionAllowed ? _delight * 4.0 : 0.0;

    final travelVigour = _travel.distance;
    final trot = travelVigour == 0
        ? 0.0
        : math.sin(_travelPhase) * 3.4 * travelVigour;

    final previous = _snapshot;
    _snapshot = PetBehaviorSnapshot(
      gaze: _gaze,
      gazeX: _gaze.dx,
      gazeY: _gaze.dy,
      browRaise: _browRaise,
      cheekLift: _cheekLift,
      earPose: (_earBase + _earKick * 0.6).clamp(-1.0, 1.0),
      beakOpen: _beakOpen,
      noseTwitch:
          _noseKick * (0.5 + 0.5 * math.sin(_clock.inMilliseconds / 26.0)),
      headTurn: _bobbing
          ? _head.translate(
              0,
              math.sin(_bobPhase) * _p.bob * 0.06 * idleWeight * _intensity,
            )
          : _head.translate(
              0,
              _asleep && _motionAllowed
                  ? (.5 + .5 * math.sin(_breathPhase * .5)) * .055
                  : 0,
            ),
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
                (_idleMotion ? breath * 0.007 * _p.breathDepth : 0.0) +
                _delight * 0.035 -
                _startle * 0.03 +
                (_bounce * 0.0035).clamp(-0.08, 0.10),
      tilt: _tilt + _travel.dx * 0.11 + _wobble,
      arousal: _arousal.clamp(0.0, 1.0),
      attention: _attention.clamp(0.0, 1.0),
      activity: _activity(),
      emotion: _emotion,
      gazeDirection: _sectors.direction,
      mood: _machine.mood,
    );

    if (PetBehaviorEngine._visiblySame(previous, _snapshot)) return;
    _notifyStateChanged();
  }
}
