import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/features/companion/domain/avatar_definition.dart';
import 'package:breakmate/features/companion/presentation/widgets/companion_pet.dart';
import 'package:breakmate/features/companion/domain/avatar_species.dart';
import 'package:breakmate/features/companion/domain/pet_animation_state.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/engine/avatar_engine_controller.dart';
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

  late final AvatarEngineController _avatarController;
  final GlobalKey<CompanionPetState> _petKey = GlobalKey<CompanionPetState>();
  String _themeId = 'grey_cat';
  String _petName = 'Mochi';
  double _scale = 6.0;
  bool _followMouse = true;
  bool _isDragging = false;
  bool _initialized = false;

  String? _speechText;
  Timer? _speechDismissTimer;
  StreamSubscription<CompanionInteractionEvent>? _speechSubscription;

  static const _speechDisplayDuration = Duration(seconds: 8);

  @override
  void initState() {
    super.initState();
    _avatarController = AvatarEngineController();
    _setupMethodChannel();
    _fetchAndApplyInitialSettings();
    _speechSubscription = EventBus.instance
        .on<CompanionInteractionEvent>()
        .listen((event) {
          if (event.interactionType != 'speech') return;
          final text = event.metadata?['text'] as String?;
          if (text == null || text.isEmpty) return;
          _showSpeech(text);
        });
  }

  void _showSpeech(String text) {
    if (!mounted) return;
    _speechDismissTimer?.cancel();
    setState(() {
      _speechText = text;
    });
    _speechDismissTimer = Timer(_speechDisplayDuration, _dismissSpeech);
  }

  void _dismissSpeech() {
    if (mounted) {
      setState(() {
        _speechText = null;
      });
    }
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

    if (mounted && !_initialized) {
      setState(() {
        _initialized = true;
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

    setState(() {
      if (config.themeId != null) {
        _themeId = config.themeId!;
      }
      if (config.scale != null && config.scale! > 0) {
        _scale = config.scale!;
      }
      if (config.petName != null && config.petName!.trim().isNotEmpty) {
        _petName = config.petName!.trim();
      }
      if (config.followMouse != null) {
        _followMouse = config.followMouse!;
      }
      if (config.state != null) {
        final s = _parseAnimationState(config.state!);
        if (s != null) {
          final clip = s.toAvatarClip();
          _avatarController.playAnimation(clip, loop: clip.isLooping);
          // The pet is drawn natively now, so an incoming state is something
          // it should notice rather than a clip to play.
          _petKey.currentState?.nudge();
        }
      }
      _initialized = true;
    });

    _avatarController.setDefinition(_avatarDefinition);
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
    _speechSubscription?.cancel();
    _speechDismissTimer?.cancel();
    _avatarController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    try {
      const MethodChannel(
        'com.leanflutter.plugins/window_manager',
      ).invokeMethod<void>('startDragging');
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }
    _isDragging = true;
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
    EventBus.instance.emit(
      CompanionInteractionEvent(interactionType: 'dragEnd'),
    );
  }

  void _handlePetTap() {
    EventBus.instance.emit(
      CompanionInteractionEvent(
        interactionType: 'petting',
        metadata: {'petName': _petName, 'themeId': _themeId},
      ),
    );
  }

  AvatarDefinition get _avatarDefinition {
    final theme = PetTheme.getTheme(_themeId);
    if (theme.avatarDefinition != null) {
      return theme.avatarDefinition!;
    }
    final species = AvatarSpecies.tryParse(_themeId) ?? AvatarSpecies.cat;
    return AvatarDefinition.fromSeed(_themeId, species: species);
  }

  @override
  Widget build(BuildContext context) {
    final avatarDef = _avatarDefinition;
    final avatarSize = (_scale * 28.0).clamp(110.0, 320.0);

    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: CompanionPet(
                key: _petKey,
                definition: avatarDef,
                size: avatarSize,
                trackCursor: _followMouse,
                onTap: _handlePetTap,
              ),
            ),
            if (_speechText != null)
              Positioned(
                top: 20,
                child: _SpeechBubble(
                  text: _speechText!,
                  onDismiss: _dismissSpeech,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text, required this.onDismiss});

  final String text;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Companion tip: $text. Double-tap to dismiss.',
      child: GestureDetector(
        onTap: onDismiss,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ExcludeSemantics(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
