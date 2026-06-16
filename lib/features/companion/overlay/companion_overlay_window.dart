import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/features/companion/domain/pet_animation_state.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/flame/companion_game.dart';
import 'package:breakmate/core/errors/error_handler.dart';

class CompanionOverlayWindow extends StatefulWidget {
  const CompanionOverlayWindow({super.key});

  @override
  State<CompanionOverlayWindow> createState() => _CompanionOverlayWindowState();
}

class _CompanionOverlayWindowState extends State<CompanionOverlayWindow> {
  static const MethodChannel _channel = MethodChannel(
    'com.breakmate.desktop/companion_data',
  );

  CompanionGame? _game;
  String _themeId = 'grey_cat';
  String _petName = 'Mochi';
  double _scale = 6.0;
  bool _isDragging = false;
  bool _gameInitialized = false;

  @override
  void initState() {
    super.initState();
    _setupMethodChannel();
    _fetchAndApplyInitialSettings();
  }

  void _setupMethodChannel() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'syncCompanionSettings':
          final Map<dynamic, dynamic>? args =
              call.arguments as Map<dynamic, dynamic>?;
          if (args != null) {
            _applySettings(Map<String, dynamic>.from(args));
          }
          break;
      }
    });
  }

  Future<void> _fetchAndApplyInitialSettings() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getInitialSettings',
      );
      if (result != null) {
        _applySettings(Map<String, dynamic>.from(result));
        EventBus.instance.emit(
          CompanionInteractionEvent(
            interactionType: 'init',
            metadata: {'themeId': _themeId, 'petName': _petName},
          ),
        );
        return;
      }
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }

    if (mounted && !_gameInitialized) {
      setState(() {
        _game = CompanionGame(
          initialTheme: PetTheme.getTheme(_themeId),
          scaleOverride: _scale,
        );
        _gameInitialized = true;
      });
      EventBus.instance.emit(
        CompanionInteractionEvent(
          interactionType: 'init',
          metadata: {'themeId': _themeId, 'petName': _petName},
        ),
      );
    }
  }

  void _applySettings(Map<String, dynamic> args) {
    if (!mounted) return;

    final newThemeId = (args['themeId'] as String?) ?? _themeId;
    final newScale = (args['scale'] as num?)?.toDouble() ?? _scale;
    final newToyType = (args['companionToyType'] as String?) ?? 'tennis_ball';
    final newTreatType = (args['companionTreatType'] as String?) ?? 'sushi';

    if (!_gameInitialized) {
      setState(() {
        _themeId = newThemeId;
        _scale = newScale;
        _game = CompanionGame(
          initialTheme: PetTheme.getTheme(newThemeId),
          scaleOverride: newScale > 0 ? newScale : 6.0,
          toyType: newToyType,
          treatType: newTreatType,
        );
        _gameInitialized = true;
      });
      _applySettingsToGame(args);
      return;
    }

    _applySettingsToGame(args);
  }

  void _applySettingsToGame(Map<String, dynamic> args) {
    if (!_gameInitialized || _game == null || !mounted) return;

    setState(() {
      if (args.containsKey('themeId')) {
        final String newThemeId = args['themeId'] as String;
        if (_themeId != newThemeId) {
          _themeId = newThemeId;
          _game!.updateTheme(PetTheme.getTheme(newThemeId));
        }
      }

      if (args.containsKey('scale')) {
        final double? newScale = (args['scale'] as num?)?.toDouble();
        if (newScale != null && newScale != _scale && newScale > 0) {
          _scale = newScale;
          _game!.updateScale(newScale);
        }
      }

      if (args.containsKey('companionToyType')) {
        final String newToyType = args['companionToyType'] as String;
        _game!.updateToyType(newToyType);
      }

      if (args.containsKey('companionTreatType')) {
        final String newTreatType = args['companionTreatType'] as String;
        _game!.updateTreatType(newTreatType);
      }

      if (args.containsKey('petName')) {
        final String? newPetName = args['petName'] as String?;
        if (newPetName != null && newPetName.trim().isNotEmpty) {
          _petName = newPetName.trim();
        }
      }

      if (args.containsKey('followMouse')) {
        final bool? followMouse = args['followMouse'] as bool?;
        if (followMouse != null) {
          _game!.updateMouseFollow({'enabled': followMouse});
        }
      }

      if (args.containsKey('wanderingEnabled')) {
        final bool? enabled = args['wanderingEnabled'] as bool?;
        if (enabled != null) {
          _game!.setWanderingEnabled(enabled);
        }
      }

      if (args.containsKey('state')) {
        final String? stateStr = args['state'] as String?;
        if (stateStr != null) {
          final PetAnimationState? s = _parseAnimationState(stateStr);
          if (s != null) _game!.triggerState(s);
        }
      }

      if (args.containsKey('mouseFollow')) {
        final Map<dynamic, dynamic>? data =
            args['mouseFollow'] as Map<dynamic, dynamic>?;
        if (data != null) _game!.updateMouseFollow(data);
      }

      if (args.containsKey('isOnBattery') ||
          args.containsKey('isAppActive') ||
          args.containsKey('isLowPowerMode')) {
        _game!.updateEnergyStatus(
          isOnBattery: args['isOnBattery'] as bool?,
          isAppActive: args['isAppActive'] as bool?,
          isLowPowerMode: args['isLowPowerMode'] as bool?,
        );
      }
    });
  }

  PetAnimationState? _parseAnimationState(String stateStr) {
    for (final state in PetAnimationState.values) {
      if (state.name == stateStr) return state;
    }
    return null;
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    // (window_manager.startDragging works on macOS and Windows)
    try {
      const MethodChannel(
        'com.leanflutter.plugins/window_manager',
      ).invokeMethod<void>('startDragging');
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }
    _isDragging = true;
    _game?.onUserInteraction('dragStart');
    EventBus.instance.emit(
      CompanionInteractionEvent(
        interactionType: 'dragStart',
        metadata: {
          'x': details.globalPosition.dx,
          'y': details.globalPosition.dy,
        },
      ),
    );
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
  }

  void _onPanEnd(DragEndDetails details) {
    _isDragging = false;
    _game?.onUserInteraction('dragEnd');
    EventBus.instance.emit(
      CompanionInteractionEvent(interactionType: 'dragEnd'),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_gameInitialized || _game == null) {
      return const SizedBox.shrink();
    }
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GameWidget(game: _game!),
      ),
    );
  }
}
