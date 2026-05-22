import 'dart:async';
import 'package:flutter/services.dart';
import 'package:standup/core/display/models/display_info.dart';
import 'package:standup/core/events/event_bus.dart';
import 'package:standup/core/events/app_events.dart';
import 'package:standup/core/utils/logger.dart';
import 'package:standup/app/dependency_injection.dart';

class DisplayManager {
  final AppLogger _logger = AppLogger();
  static const MethodChannel _channel = MethodChannel('com.standup/display_bridge');
  static const EventChannel _eventChannel = EventChannel('com.standup/display_events');

  final List<DisplayInfo> _activeDisplays = [];
  StreamSubscription? _eventSubscription;

  List<DisplayInfo> get activeDisplays => List.unmodifiable(_activeDisplays);

  Future<void> initialize() async {
    _logger.info('Initializing DisplayManager...');
    try {
      await refreshDisplays();
      _setupEventListeners();
    } catch (e) {
      _logger.error('Failed to initialize DisplayManager: $e');
    }
  }

  void _setupEventListeners() {
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen((dynamic event) {
      _handleNativeEvent(event);
    }, onError: (dynamic error) {
      _logger.error('Display event stream error: $error');
    });
  }

  Future<void> refreshDisplays() async {
    try {
      final List<dynamic>? displayData = await _channel.invokeMethod('getDisplays');
      if (displayData != null) {
        _activeDisplays.clear();
        for (var data in displayData) {
          _activeDisplays.add(DisplayInfo.fromMap(Map<String, dynamic>.from(data)));
        }
        _logger.info('Refreshed displays: ${_activeDisplays.length} detected');
        sl<EventBus>().emit(DisplayChangedEvent());
      }
    } catch (e) {
      _logger.error('Failed to refresh displays: $e');
    }
  }

  void _handleNativeEvent(dynamic event) async {
    if (event is Map) {
      final type = event['type'] as String?;
      if (type == 'display_changed') {
        _logger.info('Native display layout change detected.');
        await refreshDisplays();
      }
    }
  }

  DisplayInfo? getPrimaryDisplay() {
    try {
      return _activeDisplays.firstWhere((d) => d.isPrimary);
    } catch (_) {
      return _activeDisplays.isNotEmpty ? _activeDisplays.first : null;
    }
  }

  void dispose() {
    _eventSubscription?.cancel();
  }
}
