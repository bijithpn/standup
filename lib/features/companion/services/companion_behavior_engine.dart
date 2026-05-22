import 'dart:async';
import 'dart:math';
import 'package:standup/core/events/app_events.dart';
import 'package:standup/core/events/event_bus.dart';
import 'package:standup/core/utils/logger.dart';
import 'package:standup/app/dependency_injection.dart';
import 'package:standup/features/settings/settings_repository.dart';

class CompanionBehaviorEngine {
  CompanionBehaviorEngine({EventBus? eventBus})
      : _eventBus = eventBus ?? EventBus.instance,
        _logger = AppLogger();

  final EventBus _eventBus;
  final AppLogger _logger;
  final Random _random = Random();

  Timer? _behaviorTimer;
  Timer? _wanderTimer;
  bool _isEnabled = true; // Default true; disabled only when explicitly set or settings say so
  int _idleCycles = 0;
  static const _maxIdleCyclesBeforeAction = 12;

  void start() {
    stop();
    try {
      final settingsRepo = sl<SettingsRepository>();
      if (!settingsRepo.currentSettings.companionEnabled) {
        return;
      }
    } catch (_) {
      // If DI fails (e.g. background isolate), do not start
      return;
    }
    if (!_isEnabled) return;

    _behaviorTimer = Timer.periodic(const Duration(seconds: 5), _onTick);
    _logger.info('Companion behavior engine started');
  }

  void stop() {
    _behaviorTimer?.cancel();
    _behaviorTimer = null;
    _wanderTimer?.cancel();
    _wanderTimer = null;
  }

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (enabled) {
      start();
    } else {
      stop();
    }
  }

  void _onTick(Timer timer) {
    if (!_isEnabled) {
      stop();
      return;
    }
    try {
      final settingsRepo = sl<SettingsRepository>();
      if (!settingsRepo.currentSettings.companionEnabled) {
        stop();
        return;
      }
    } catch (_) {
      // Safe fallback
    }

    _idleCycles++;

    if (_idleCycles >= _maxIdleCyclesBeforeAction) {
      _idleCycles = 0;
      _triggerRandomBehavior();
    }
  }

  void _triggerRandomBehavior() {
    final behavior = _random.nextDouble();

    if (behavior < 0.4) { // Increased blink frequency
      _triggerBlink();
    } else if (behavior < 0.6) {
      _triggerStretch();
    } else if (behavior < 0.75) {
      _triggerLookAround();
    } else if (behavior < 0.9) {
      _triggerYawn();
    } else {
      _triggerHappy();
    }
  }

  void _triggerBlink() {
    _eventBus.emit(CompanionInteractionEvent(
      interactionType: 'blink',
      metadata: {'source': 'behavior_engine'},
    ));
    _logger.info('Companion: blink behavior');
  }

  void _triggerStretch() {
    _eventBus.emit(CompanionInteractionEvent(
      interactionType: 'stretch',
      metadata: {'source': 'behavior_engine'},
    ));
    _logger.info('Companion: stretch behavior');
  }

  void _triggerLookAround() {
    _eventBus.emit(CompanionInteractionEvent(
      interactionType: 'lookAround',
      metadata: {'source': 'behavior_engine'},
    ));
    _logger.info('Companion: look around behavior');
  }

  void _triggerYawn() {
    _eventBus.emit(CompanionInteractionEvent(
      interactionType: 'yawn',
      metadata: {'source': 'behavior_engine'},
    ));
    _logger.info('Companion: yawn behavior');
  }

  void _triggerHappy() {
    _eventBus.emit(CompanionInteractionEvent(
      interactionType: 'happy',
      metadata: {'source': 'behavior_engine'},
    ));
    _logger.info('Companion: happy behavior');
  }

  void onUserInteraction() {
    _idleCycles = 0;
  }

  void dispose() {
    stop();
  }
}
