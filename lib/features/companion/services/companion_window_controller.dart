import 'dart:async';
import 'package:standup/core/events/app_events.dart';
import 'package:standup/core/events/event_bus.dart';
import 'package:standup/core/services/window_service.dart';
import 'package:standup/core/utils/logger.dart';

class CompanionWindowController {
  CompanionWindowController({
    WindowService? windowService,
    EventBus? eventBus,
  })  : _windowService = windowService ?? WindowService.instance,
        _eventBus = eventBus ?? EventBus.instance,
        _logger = AppLogger();

  final WindowService _windowService;
  final EventBus _eventBus;
  final AppLogger _logger;

  bool _isVisible = false;
  double _x = 0;
  double _y = 0;
  double _opacity = 0.9;
  bool _acceptsMouse = true;

  bool get isVisible => _isVisible;
  double get x => _x;
  double get y => _y;

  Future<void> show() async {
    if (_isVisible) return;
    _isVisible = true;
    await _windowService.showWindow();
    await _windowService.setWindowLevel('floating');
    await _windowService.setIgnoresMouseEvents(!_acceptsMouse);
    await _windowService.setHasShadow(false);
    await _windowService.setAcceptsMouseMovedEvents(true);
    await _windowService.setWindowOpacity(_opacity);
    _eventBus.emit(OverlayShownEvent(overlayType: 'companion'));
    _logger.info('Companion window shown');
  }

  Future<void> hide() async {
    if (!_isVisible) return;
    _isVisible = false;
    await _windowService.hideWindow();
    _eventBus.emit(OverlayHiddenEvent(overlayType: 'companion'));
    _logger.info('Companion window hidden');
  }

  Future<void> toggle() async {
    if (_isVisible) {
      await hide();
    } else {
      await show();
    }
  }

  Future<void> setPosition(double x, double y) async {
    _x = x;
    _y = y;
    await _windowService.setWindowPosition(x: x, y: y);
    _eventBus.emit(CompanionPositionChangedEvent(x: x, y: y));
  }

  Future<void> setOpacity(double opacity) async {
    _opacity = opacity.clamp(0.1, 1.0);
    await _windowService.setWindowOpacity(_opacity);
  }

  Future<void> setAcceptsMouse(bool accepts) async {
    _acceptsMouse = accepts;
    await _windowService.setIgnoresMouseEvents(!accepts);
  }

  Future<Map<String, dynamic>> getPosition() async {
    final pos = await _windowService.getWindowPosition();
    _x = pos['x'] as double;
    _y = pos['y'] as double;
    return pos;
  }

  Future<void> bringToFront() async {
    await _windowService.orderFrontRegardless();
  }
}
