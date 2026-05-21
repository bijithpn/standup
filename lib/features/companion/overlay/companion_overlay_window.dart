import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:standup/core/events/app_events.dart';
import 'package:standup/core/events/event_bus.dart';
import 'package:standup/features/companion/domain/cat_animation_state.dart';
import 'package:standup/features/companion/domain/cat_theme.dart';
import 'package:standup/features/companion/flame/companion_game.dart';

class CompanionOverlayWindow extends StatefulWidget {
  const CompanionOverlayWindow({super.key});

  @override
  State<CompanionOverlayWindow> createState() => _CompanionOverlayWindowState();
}

class _CompanionOverlayWindowState extends State<CompanionOverlayWindow> {
  static const MethodChannel _channel = MethodChannel('com.breakmate.macos/companion_data');

  late CompanionGame _game;
  String _themeId = 'grey_cat'; // default; will be overwritten by _fetchAndApplyInitialSettings
  String _petName = 'Mochi';
  bool _isDragging = false;
  bool _gameInitialized = false;

  @override
  void initState() {
    super.initState();
    _setupMethodChannel();
    // Pull the correct initial settings from native *after* registering the handler.
    // This avoids the race condition where native pushes the theme before Flutter
    // has set up its method call handler.
    _fetchAndApplyInitialSettings();
  }

  /// Pulls the initial companion configuration from the native side.
  /// Native stored the spawn args in `pendingInitialArgs` and returns them here.
  Future<void> _fetchAndApplyInitialSettings() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getInitialSettings');
      if (result != null) {
        final String newThemeId = (result['themeId'] as String?) ?? _themeId;
        final String? newPetName = result['petName'] as String?;
        final double? newScale = (result['scale'] as num?)?.toDouble();

        _themeId = newThemeId;
        if (newPetName != null && newPetName.trim().isNotEmpty) {
          _petName = newPetName.trim();
        }

        if (!mounted) return;
        setState(() {
          _game = CompanionGame(
            initialTheme: CatTheme.getTheme(_themeId),
            scaleOverride: newScale ?? 0.0,
          );
          _gameInitialized = true;
        });

        EventBus.instance.emit(CompanionInteractionEvent(
          interactionType: 'init',
          metadata: {'themeId': _themeId, 'petName': _petName},
        ));
        return;
      }
    } catch (_) {
      // Native method not available or returned error; fall through to default init
    }

    // Fallback: initialize with the default theme if pull failed
    if (mounted) {
      setState(() {
        _game = CompanionGame(
          initialTheme: CatTheme.getTheme(_themeId),
          scaleOverride: 0.0,
        );
        _gameInitialized = true;
      });
      _emitInitialEvents();
    }
  }

  void _emitInitialEvents() {
    EventBus.instance.emit(CompanionInteractionEvent(
      interactionType: 'init',
      metadata: {'themeId': _themeId, 'petName': _petName},
    ));
  }

  void _setupMethodChannel() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'syncCompanionSettings':
          final Map<dynamic, dynamic>? args = call.arguments as Map<dynamic, dynamic>?;
          if (args == null) return;

          setState(() {
            if (args.containsKey('themeId')) {
              final String newThemeId = args['themeId'] as String;
              _themeId = newThemeId;
              _game.updateTheme(CatTheme.getTheme(newThemeId));
            }

            if (args.containsKey('scale')) {
              final double? newScale = (args['scale'] as num?)?.toDouble();
              if (newScale != null) {
                _game.updateScale(newScale);
              }
            }

            if (args.containsKey('petName')) {
              final String? newPetName = args['petName'] as String?;
              if (newPetName != null && newPetName.trim().isNotEmpty) {
                _petName = newPetName.trim();
              }
            }

            if (args.containsKey('wanderingEnabled')) {
              final bool? enabled = args['wanderingEnabled'] as bool?;
              if (enabled != null) {
                _game.setWanderingEnabled(enabled);
              }
            }

            if (args.containsKey('state')) {
              final String? stateStr = args['state'] as String?;
              if (stateStr != null) {
                final CatAnimationState? matchingState = _parseAnimationState(stateStr);
                if (matchingState != null) {
                  _game.triggerState(matchingState);
                }
              }
            }

            if (args.containsKey('mouseFollow')) {
              final Map<dynamic, dynamic>? mouseFollowData = args['mouseFollow'] as Map<dynamic, dynamic>?;
              if (mouseFollowData != null) {
                _game.updateMouseFollow(mouseFollowData);
              }
            }
          });
          break;
      }
    });
  }

  CatAnimationState? _parseAnimationState(String stateStr) {
    for (final state in CatAnimationState.values) {
      if (state.name == stateStr) {
        return state;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    _isDragging = true;
    _game.onUserInteraction('dragStart');
    EventBus.instance.emit(CompanionInteractionEvent(
      interactionType: 'dragStart',
      metadata: {'x': details.globalPosition.dx, 'y': details.globalPosition.dy},
    ));
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    _channel.invokeMethod('syncCompanionSettings', {
      'positionDelta': {
        'dx': details.delta.dx,
        'dy': details.delta.dy,
      },
    });
  }

  void _onPanEnd(DragEndDetails details) {
    _isDragging = false;
    _game.onUserInteraction('dragEnd');
    EventBus.instance.emit(CompanionInteractionEvent(
      interactionType: 'dragEnd',
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (!_gameInitialized) {
      // Show nothing while we wait for the initial settings pull.
      // This is nearly instant (one method channel round-trip).
      return const SizedBox.shrink();
    }
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GameWidget(game: _game),
      ),
    );
  }
}
