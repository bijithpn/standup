import 'package:flutter/material.dart';
import 'package:breakmate/core/display/models/display_info.dart';
import 'package:breakmate/core/display/services/display_manager.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/events/app_events.dart';

class DisplayController extends ChangeNotifier {
  final DisplayManager _displayManager;
  final EventBus _eventBus;

  List<DisplayInfo> _displays = [];

  List<DisplayInfo> get displays => _displays;

  DisplayController(this._displayManager, this._eventBus) {
    _init();
  }

  void _init() {
    _displays = _displayManager.activeDisplays;
    _eventBus.on<DisplayChangedEvent>().listen((event) {
      _displays = _displayManager.activeDisplays;
      notifyListeners();
    });
  }
}
