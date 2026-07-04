import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/features/companion/domain/pet_animation_state.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/flame/companion_game.dart';
import 'package:breakmate/core/errors/error_handler.dart';

import 'package:breakmate/core/ipc/overlay_config.dart';

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
            _applySettings(OverlayConfig.fromJson(Map<String, dynamic>.from(args)));
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
        _applySettings(OverlayConfig.fromJson(Map<String, dynamic>.from(result)));
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

  void _applySettings(OverlayConfig config) {
    if (!mounted) return;

    final newThemeId = config.themeId ?? _themeId;
    final newScale = config.scale ?? _scale;
    final newToyType = config.companionToyType ?? 'tennis_ball';
    final newTreatType = config.companionTreatType ?? 'sushi';

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
      _applySettingsToGame(config);
      return;
    }

    _applySettingsToGame(config);
  }

  void _applySettingsToGame(OverlayConfig config) {
    if (!_gameInitialized || _game == null || !mounted) return;

    setState(() {
      if (config.themeId != null) {
        final String newThemeId = config.themeId!;
        if (_themeId != newThemeId) {
          _themeId = newThemeId;
          _game!.updateTheme(PetTheme.getTheme(newThemeId));
        }
      }

      if (config.scale != null) {
        final double newScale = config.scale!;
        if (newScale != _scale && newScale > 0) {
          _scale = newScale;
          _game!.updateScale(newScale);
        }
      }

      if (config.companionToyType != null) {
        final String newToyType = config.companionToyType!;
        _game!.updateToyType(newToyType);
      }

      if (config.companionTreatType != null) {
        final String newTreatType = config.companionTreatType!;
        _game!.updateTreatType(newTreatType);
      }

      if (config.petName != null) {
        final String newPetName = config.petName!;
        if (newPetName.trim().isNotEmpty) {
          _petName = newPetName.trim();
        }
      }

      if (config.followMouse != null) {
        final bool followMouse = config.followMouse!;
        _game!.updateMouseFollow({'enabled': followMouse});
      }

      if (config.wanderingEnabled != null) {
        final bool enabled = config.wanderingEnabled!;
        _game!.setWanderingEnabled(enabled);
      }

      if (config.state != null) {
        final String stateStr = config.state!;
        final PetAnimationState? s = _parseAnimationState(stateStr);
        if (s != null) _game!.triggerState(s);
      }

      if (config.mouseFollow != null) {
        _game!.updateMouseFollow(config.mouseFollow!);
      }

      if (config.isOnBattery != null ||
          config.isAppActive != null ||
          config.isLowPowerMode != null) {
        _game!.updateEnergyStatus(
          isOnBattery: config.isOnBattery,
          isAppActive: config.isAppActive,
          isLowPowerMode: config.isLowPowerMode,
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
