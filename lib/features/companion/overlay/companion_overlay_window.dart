import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:standup/features/companion/domain/cat_animation_state.dart';
import 'package:standup/features/companion/domain/cat_theme.dart';
import 'package:standup/features/companion/flame/companion_game.dart';
import 'package:window_manager/window_manager.dart';

class CompanionOverlayWindow extends StatefulWidget {
  const CompanionOverlayWindow({super.key});

  @override
  State<CompanionOverlayWindow> createState() => _CompanionOverlayWindowState();
}

class _CompanionOverlayWindowState extends State<CompanionOverlayWindow> {
  static const MethodChannel _channel = MethodChannel('com.breakmate.macos/companion_data');

  late CompanionGame _game;
  String _themeId = 'grey_cat';

  @override
  void initState() {
    super.initState();

    // 1. Initialize Flame CompanionGame — auto-scale enabled (scaleOverride=0)
    _game = CompanionGame(
      currentTheme: CatTheme.getTheme(_themeId),
      scaleOverride: 0.0, // 0 = auto-scale to fill window
      initialAnimationState: CatAnimationState.idle,
    );

    // 2. Set up native method channel listener to receive state and setting updates.
    _setupMethodChannel();
  }

  void _setupMethodChannel() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'syncCompanionSettings') {
        final Map<dynamic, dynamic>? args = call.arguments as Map<dynamic, dynamic>?;
        if (args == null) return;

        setState(() {
          // Parse theme changes
          if (args.containsKey('themeId')) {
            final String newThemeId = args['themeId'] as String;
            _themeId = newThemeId;
            _game.updateTheme(CatTheme.getTheme(newThemeId));
          }

          // Parse scale factor adjustments (0 = auto)
          if (args.containsKey('scale')) {
            final double? newScale = (args['scale'] as num?)?.toDouble();
            if (newScale != null) {
              _game.updateScale(newScale);
            }
          }

          // Parse AI wandering toggles
          if (args.containsKey('wanderingEnabled')) {
            final bool? enabled = args['wanderingEnabled'] as bool?;
            if (enabled != null) {
              _game.setWanderingEnabled(enabled);
            }
          }

          // Parse dynamic behavior or alert state triggers
          if (args.containsKey('state')) {
            final String? stateStr = args['state'] as String?;
            if (stateStr != null) {
              final CatAnimationState? matchingState = _parseAnimationState(stateStr);
              if (matchingState != null) {
                _game.triggerState(matchingState);
              }
            }
          }
        });
      }
    });
  }

  /// Safe parser mapping string values to companion animation states.
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

  @override
  Widget build(BuildContext context) {
    // Ensures a fully transparent overlay framework without standard background cards.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (details) {
          windowManager.startDragging();
        },
        child: GameWidget(
          game: _game,
        ),
      ),
    );
  }
}
