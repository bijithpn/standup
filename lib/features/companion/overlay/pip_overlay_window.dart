// pip_overlay_window.dart
//
// A compact "Picture-in-Picture" companion window where the pet roams freely
// inside a small, draggable, always-on-top panel.  Interaction buttons float
// at the bottom of the window so the user can engage with the pet without
// interrupting their workflow.
//
// Architecture:
//   • This widget is the Flutter UI root for the `pipMain` entrypoint.
//   • A full CompanionGame runs inside the window (same Flame game as the
//     full-screen companion, but the window is only 280×320 px by default).
//   • Interaction buttons sit in a translucent bottom bar and fire FSM events
//     directly via EventBus so the Flame game reacts in real-time.
//   • The native side (PiPWindowManager.swift) owns the window chrome and
//     handles drag-to-move via the standard NSWindow dragging mechanism.

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/features/companion/domain/pet_animation_state.dart';
import 'package:breakmate/features/companion/domain/pet_state_machine.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/flame/companion_game.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PiPOverlayWindow — root widget
// ─────────────────────────────────────────────────────────────────────────────

class PiPOverlayWindow extends StatefulWidget {
  const PiPOverlayWindow({super.key});

  @override
  State<PiPOverlayWindow> createState() => _PiPOverlayWindowState();
}

class _PiPOverlayWindowState extends State<PiPOverlayWindow>
    with SingleTickerProviderStateMixin {
  static const MethodChannel _channel = MethodChannel(
    'com.breakmate.desktop/pip_data',
  );

  CompanionGame? _game;
  String _themeId = 'grey_cat';
  String _petName = 'Mochi';
  double _scale = 3.0; // Smaller scale fits the compact window
  bool _gameInitialized = false;

  // Controls whether the interaction button bar is visible.
  bool _showButtons = true;
  late final AnimationController _buttonFade;
  late final Animation<double> _buttonOpacity;

  @override
  void initState() {
    super.initState();
    _buttonFade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1.0,
    );
    _buttonOpacity = _buttonFade;
    _channel.setMethodCallHandler(_handleMethodCall);
    _fetchInitialSettings();
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    _buttonFade.dispose();
    super.dispose();
  }

  // ── Method channel ──────────────────────────────────────────────────────

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'syncPiPSettings':
        final args = call.arguments as Map<dynamic, dynamic>?;
        if (args != null) _applySettings(Map<String, dynamic>.from(args));
      case 'toggleButtons':
        _toggleButtonBar();
    }
  }

  Future<void> _fetchInitialSettings() async {
    try {
      final result =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('getInitialSettings');
      if (result != null) {
        _applySettings(Map<String, dynamic>.from(result));
        return;
      }
    } catch (_) {
      // Channel unavailable — fall through to defaults.
    }
    _initGameWithDefaults();
  }

  void _initGameWithDefaults() {
    if (!mounted || _gameInitialized) return;
    setState(() {
      _game = CompanionGame(
        initialTheme: PetTheme.getTheme(_themeId),
        scaleOverride: _scale,
      );
      _gameInitialized = true;
    });
  }

  void _applySettings(Map<String, dynamic> args) {
    if (!mounted) return;
    final newThemeId = (args['themeId'] as String?) ?? _themeId;
    final newScale = (args['scale'] as num?)?.toDouble() ?? _scale;
    final newPetName = (args['petName'] as String?) ?? _petName;

    if (!_gameInitialized) {
      setState(() {
        _themeId = newThemeId;
        _scale = newScale > 0 ? newScale : 3.0;
        _petName = newPetName;
        _game = CompanionGame(
          initialTheme: PetTheme.getTheme(_themeId),
          scaleOverride: _scale,
        );
        _gameInitialized = true;
      });
    } else {
      setState(() {
        if (newThemeId != _themeId) {
          _themeId = newThemeId;
          _game?.updateTheme(PetTheme.getTheme(newThemeId));
        }
        if (newScale > 0 && newScale != _scale) {
          _scale = newScale;
          _game?.updateScale(newScale);
        }
        if (newPetName != _petName) {
          _petName = newPetName;
        }
      });
    }
  }

  // ── Interaction button actions ──────────────────────────────────────────

  void _feed() {
    EventBus.instance.emit(
      CompanionInteractionEvent(
        interactionType: 'feed',
        metadata: {'source': 'pip'},
      ),
    );
    _game?.petService.handleEvent(PetEvent.petFed);
    _game?.triggerState(PetAnimationState.excited);
    _flashFeedback('😋 Yum!');
  }

  void _play() {
    EventBus.instance.emit(
      CompanionInteractionEvent(
        interactionType: 'play',
        metadata: {'source': 'pip'},
      ),
    );
    _game?.petService.handleEvent(PetEvent.petPlayed);
    _game?.triggerState(PetAnimationState.hop);
    _flashFeedback('🎉 Yay!');
  }

  void _petAction() {
    EventBus.instance.emit(
      CompanionInteractionEvent(
        interactionType: 'tap',
        metadata: {'source': 'pip'},
      ),
    );
    _game?.petService.handleEvent(PetEvent.userClick);
    _flashFeedback('💕 Aww!');
  }

  void _wave() {
    EventBus.instance.emit(
      CompanionInteractionEvent(
        interactionType: 'wave',
        metadata: {'source': 'pip'},
      ),
    );
    _game?.triggerState(PetAnimationState.notification);
    _flashFeedback('👋 Hi!');
  }

  String? _feedbackText;

  void _flashFeedback(String text) {
    setState(() => _feedbackText = text);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _feedbackText = null);
    });
  }

  void _toggleButtonBar() {
    setState(() => _showButtons = !_showButtons);
    if (_showButtons) {
      _buttonFade.forward();
    } else {
      _buttonFade.reverse();
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── Flame game fills the whole window ───────────────────────────
          if (_gameInitialized && _game != null)
            Positioned.fill(
              child: GameWidget(game: _game!),
            )
          else
            const Positioned.fill(
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Colors.white38,
                ),
              ),
            ),

          // ── Floating pet name badge ─────────────────────────────────────
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Center(
              child: _PetNameBadge(name: _petName),
            ),
          ),

          // ── Floating feedback toast ─────────────────────────────────────
          if (_feedbackText != null)
            Positioned(
              top: 34,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: _FeedbackToast(
                    key: ValueKey(_feedbackText),
                    text: _feedbackText!,
                  ),
                ),
              ),
            ),

          // ── Interaction button bar at bottom ────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FadeTransition(
              opacity: _buttonOpacity,
              child: _InteractionBar(
                onFeed: _feed,
                onPlay: _play,
                onPet: _petAction,
                onWave: _wave,
                onToggle: _toggleButtonBar,
                isVisible: _showButtons,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PetNameBadge
// ─────────────────────────────────────────────────────────────────────────────

class _PetNameBadge extends StatelessWidget {
  const _PetNameBadge({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        name,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FeedbackToast
// ─────────────────────────────────────────────────────────────────────────────

class _FeedbackToast extends StatelessWidget {
  const _FeedbackToast({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A2E),
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _InteractionBar
// ─────────────────────────────────────────────────────────────────────────────

class _InteractionBar extends StatelessWidget {
  const _InteractionBar({
    required this.onFeed,
    required this.onPlay,
    required this.onPet,
    required this.onWave,
    required this.onToggle,
    required this.isVisible,
  });

  final VoidCallback onFeed;
  final VoidCallback onPlay;
  final VoidCallback onPet;
  final VoidCallback onWave;
  final VoidCallback onToggle;
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ActionButton(
              emoji: '🍣',
              label: 'Feed',
              onTap: onFeed,
            ),
            _ActionButton(
              emoji: '🎾',
              label: 'Play',
              onTap: onPlay,
            ),
            _ActionButton(
              emoji: '🤝',
              label: 'Pet',
              onTap: onPet,
            ),
            _ActionButton(
              emoji: '👋',
              label: 'Wave',
              onTap: onWave,
            ),
            // Collapse button
            GestureDetector(
              onTap: onToggle,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white54,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ActionButton
// ─────────────────────────────────────────────────────────────────────────────

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final VoidCallback onTap;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 150),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _press, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _handleTap() {
    _press.forward().then((_) => _press.reverse());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  widget.emoji,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 9,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
