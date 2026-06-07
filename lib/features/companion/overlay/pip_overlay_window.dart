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
//   • InteractionBar sits at the bottom with throw-ball, give-treat,
//     quiet/hide toggle, and collapse/expand controls.
//   • A 24 px drag handle at the top routes pan gestures to the native
//     window-move mechanism (CompanionWindowManager.startDrag) rather than
//     to pet-interaction events (Req 1.4, 1.5).
//   • A GestureDetector on the pet area routes taps, double-taps, and
//     drag gestures to InteractionController methods (Req 4.1, 5.1, 6.1).
//   • Mouse-move / hover events are routed to InteractionController.onPetPetted()
//     using CursorTracker velocity (Req 6.1).

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/native/native_bridge.dart';
import 'package:breakmate/core/ipc/ipc_bridge.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/flame/companion_game.dart';
import 'package:breakmate/features/companion/interaction/interaction_controller.dart';
import 'package:breakmate/features/companion/services/companion_window_manager.dart';
import 'package:breakmate/features/companion/services/display_manager.dart';

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

  // ── Game ────────────────────────────────────────────────────────────────
  CompanionGame? _game;
  String _themeId = 'grey_cat';
  String _petName = 'Mochi';
  double _scale = 3.0;
  bool _gameInitialized = false;

  // ── Services (lazy singletons) ──────────────────────────────────────────
  late final CompanionWindowManager _windowManager = CompanionWindowManager(
    displayManager: NativeDisplayManager(),
  );
  final InteractionController _interactionController = InteractionController();

  // ── Click-Through State ──────────────────────────────────────────────────
  bool _clickThrough = false;
  bool _acceptsMouse = true;
  Timer? _clickThroughTimer;

  // ── InteractionBar state ────────────────────────────────────────────────

  /// Whether the interaction bar is fully expanded (showing all buttons).
  bool _barExpanded = true;

  /// AnimationController for collapse/expand (200 ms per spec Req 16.3).
  late final AnimationController _barAnim;
  late final Animation<double> _barWidth; // drives the collapsible section

  // ── Throw ball button state (Req 16.4) ──────────────────────────────────

  /// True when ThrowableObjectManager.maxActiveThrowables == 5.
  bool _throwDisabled = false;

  /// Subscription listening for ThrowRejectedEvent and ThrowableDisposedEvent.
  StreamSubscription<AppEvent>? _throwEventSub;

  // ── Treat button cooldown state (Req 16.5) ───────────────────────────────

  /// True while the 10-second cooldown after giving a treat is active.
  bool _treatOnCooldown = false;
  Timer? _treatCooldownTimer;

  /// Subscription listening for TreatSpawnFailedEvent (for error indicator).
  StreamSubscription<AppEvent>? _treatEventSub;

  // ── Quiet / hide toggle state (Req 16.6) ────────────────────────────────

  // ── PiP custom settings ──────────────────────────────────────────────────
  String _pipBackgroundStyle = 'dark';
  double _pipOpacity = 0.9;
  bool _pipDraggableClickable = true;

  // ── Drag gesture tracking for pet area (Task 9.2) ───────────────────────

  /// The global position where the current drag gesture began.
  Offset? _dragStartPosition;

  /// The last recorded global position during a drag (used to compute delta).
  Offset? _lastDragPosition;

  // ── Feedback toast ──────────────────────────────────────────────────────
  String? _feedbackText;

  @override
  void initState() {
    super.initState();

    // Bar animation — 200 ms as required by Req 16.3.
    _barAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1.0, // 1 = expanded
    );
    _barWidth = _barAnim; // used directly as fraction in _InteractionBar

    _channel.setMethodCallHandler(_handleMethodCall);
    _fetchInitialSettings();
    _interactionController.initialize();

    // Periodic click-through check every 100 ms.
    _clickThroughTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _checkClickThrough();
    });

    // Subscribe to throw-related events to update the throw button state.
    _throwEventSub = EventBus.instance.stream.listen(_handleThrowEvent);

    // Subscribe to treat failure events for future error indicator wiring.
    _treatEventSub = EventBus.instance.stream.listen(_handleTreatEvent);
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    _barAnim.dispose();
    _interactionController.dispose();
    _throwEventSub?.cancel();
    _treatEventSub?.cancel();
    _treatCooldownTimer?.cancel();
    _clickThroughTimer?.cancel();
    super.dispose();
  }

  // ── Event listeners ──────────────────────────────────────────────────────

  /// Keeps the throw-ball button disabled/enabled in sync with the number of
  /// active throwables (Req 16.4).
  void _handleThrowEvent(AppEvent event) {
    if (!mounted) return;

    // A throwable was spawned — check whether we're now at the cap.
    if (event is ThrowableSpawnedEvent || event is ThrowableDisposedEvent) {
      // Recompute disabled state by counting active throwables from the game.
      // The game exposes its ThrowableObjectManager via the InteractionController
      // dependency; we approximate by re-querying the event type.
      // ThrowableSpawnedEvent → might be at cap; ThrowableDisposedEvent → can
      // re-enable.  We rely on InteractionController.throwToy() silently no-
      // opping when at cap, so the visual state merely needs to mirror cap.
      if (event is ThrowableSpawnedEvent) {
        // We don't have direct count access here; rely on ThrowRejectedEvent.
      }
      if (event is ThrowableDisposedEvent) {
        if (_throwDisabled) setState(() => _throwDisabled = false);
      }
    }

    if (event is ThrowRejectedEvent) {
      // Manager rejected because cap == 5.  Disable the button.
      if (!_throwDisabled) setState(() => _throwDisabled = true);
    }
  }

  void _handleTreatEvent(AppEvent event) {
    if (!mounted) return;
    // TreatSpawnFailedEvent is handled visually by the treat button; no extra
    // action needed here beyond what _giveTreat already does.
  }

  // ── Method channel ──────────────────────────────────────────────────────

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'syncPiPSettings':
        final args = call.arguments as Map<dynamic, dynamic>?;
        if (args != null) _applySettings(Map<String, dynamic>.from(args));
      case 'toggleButtons':
        _toggleBar();
    }
  }

  Future<void> _fetchInitialSettings() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getInitialSettings',
      );
      if (result != null) {
        _applySettings(Map<String, dynamic>.from(result));
        // Initialize the window manager so size, position, and
        // non-activating style (WS_EX_NOACTIVATE on Windows) are applied
        // before the window becomes interactive.
        await _windowManager.initialize();
        return;
      }
    } catch (_) {
      // Channel unavailable — fall through to defaults.
    }
    _initGameWithDefaults();
    await _windowManager.initialize();
  }

  void _initGameWithDefaults() {
    if (!mounted || _gameInitialized) return;
    setState(() {
      _game = CompanionGame(
        initialTheme: PetTheme.getTheme(_themeId),
        scaleOverride: _scale,
        isPiP: true,
      );
      _gameInitialized = true;
    });
  }

  void _applySettings(Map<String, dynamic> args) {
    if (!mounted) return;
    final newThemeId = (args['themeId'] as String?) ?? _themeId;
    final newScale = (args['scale'] as num?)?.toDouble() ?? _scale;
    final newPetName = (args['petName'] as String?) ?? _petName;
    final newClickThrough = (args['clickThrough'] as bool?) ?? _clickThrough;
    final newPipBackgroundStyle =
        (args['pipBackgroundStyle'] as String?) ?? _pipBackgroundStyle;
    final newPipOpacity =
        (args['pipOpacity'] as num?)?.toDouble() ?? _pipOpacity;
    final newPipDraggableClickable =
        (args['pipDraggableClickable'] as bool?) ?? _pipDraggableClickable;
    final newToyType = (args['companionToyType'] as String?) ?? 'tennis_ball';
    final newTreatType = (args['companionTreatType'] as String?) ?? 'sushi';

    if (!_gameInitialized) {
      setState(() {
        _themeId = newThemeId;
        _scale = newScale > 0 ? newScale : 3.0;
        _petName = newPetName;
        _clickThrough = newClickThrough;
        _pipBackgroundStyle = newPipBackgroundStyle;
        _pipOpacity = newPipOpacity;
        _pipDraggableClickable = newPipDraggableClickable;
        _game = CompanionGame(
          initialTheme: PetTheme.getTheme(_themeId),
          scaleOverride: _scale,
          isPiP: true,
          toyType: newToyType,
          treatType: newTreatType,
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
        if (newClickThrough != _clickThrough) {
          _clickThrough = newClickThrough;
        }
        if (newToyType != _game?.toyType) {
          _game?.updateToyType(newToyType);
        }
        if (newTreatType != _game?.treatType) {
          _game?.updateTreatType(newTreatType);
        }
        _pipBackgroundStyle = newPipBackgroundStyle;
        _pipOpacity = newPipOpacity;
        _pipDraggableClickable = newPipDraggableClickable;
      });
    }
    _windowManager.setOpacity(_pipOpacity);
    _checkClickThrough();
  }

  Future<void> _checkClickThrough() async {
    // If draggable/clickable is disabled, the entire window ignores mouse events
    if (!_pipDraggableClickable) {
      if (_acceptsMouse) {
        _acceptsMouse = false;
        await _windowManager.setAcceptsMouse(false);
      }
      return;
    }

    if (!_clickThrough) {
      if (!_acceptsMouse) {
        _acceptsMouse = true;
        await _windowManager.setAcceptsMouse(true);
      }
      return;
    }

    try {
      final pos = await _windowManager.getPosition();
      final size = _windowManager.currentSize;
      final cursorPos = await NativeBridge.getCursorPosition();

      double top = pos.dy;

      if (Platform.isMacOS) {
        final displays = await _windowManager.displayManager
            ?.enumerateDisplays();
        double primaryScreenHeight = 1080.0;
        if (displays != null && displays.isNotEmpty) {
          final primary = displays.firstWhere(
            (d) => d.isPrimary,
            orElse: () => displays.first,
          );
          primaryScreenHeight = primary.rect.height;
        }
        // macOS coordinate origin is bottom-left, flip to top-left
        top = primaryScreenHeight - pos.dy - size.height;
      }

      final windowRect = Rect.fromLTWH(pos.dx, top, size.width, size.height);

      bool accepts = true;
      if (windowRect.contains(cursorPos)) {
        final localX = cursorPos.dx - windowRect.left;
        final localY = cursorPos.dy - windowRect.top;

        // Inside the 8px margin of the card?
        final inCard =
            localX >= 8.0 &&
            localX <= (size.width - 8.0) &&
            localY >= 8.0 &&
            localY <= (size.height - 8.0);

        if (inCard) {
          // Inside the drag handle or the interaction bar area of the card?
          final inDragHandle = localY >= 8.0 && localY <= 32.0;
          final inInteractionBar =
              localY >= (size.height - 8.0 - 44.0) &&
              localY <= (size.height - 8.0);
          accepts = inDragHandle || inInteractionBar;
        } else {
          accepts = false; // Margin is transparent / click-through
        }
      } else {
        accepts = true;
      }

      if (_acceptsMouse != accepts) {
        _acceptsMouse = accepts;
        await _windowManager.setAcceptsMouse(accepts);
      }
    } catch (e) {
      // Ignore or log error
    }
  }

  // ── InteractionBar actions ────────────────────────────────────────────────

  String _getToyEmoji() {
    switch (_game?.toyType) {
      case 'toy_mouse':
        return '🐭';
      case 'pink_yarn':
        return '🧶';
      case 'orange_yarn':
        return '🧶';
      case 'tennis_ball':
      default:
        return '🎾';
    }
  }

  String _getTreatEmoji() {
    switch (_game?.treatType) {
      case 'bone':
        return '🦴';
      case 'carrot':
        return '🥕';
      case 'sushi':
      default:
        return '🍣';
    }
  }

  /// Called when the 🎾 throw ball button is tapped.
  ///
  /// Delegates to [InteractionController.throwToy].  The controller will
  /// silently no-op if the cap is reached; the button is already visually
  /// disabled in that case (Req 16.4, 7.9).
  void _throwBall() {
    if (_throwDisabled) return;
    _interactionController.throwToy();
    _flashFeedback('🎾 Fetch!');
  }

  /// Called when the 🍣 give treat button is tapped.
  ///
  /// Enforces the 10-second visual cooldown on top of the controller-side
  /// cooldown so the button appears disabled (Req 16.5, 8.9).
  void _giveTreat() {
    if (_treatOnCooldown) return;
    _interactionController.giveTreat();
    _flashFeedback('🍣 Treat!');

    setState(() => _treatOnCooldown = true);
    _treatCooldownTimer?.cancel();
    _treatCooldownTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) setState(() => _treatOnCooldown = false);
    });
  }

  /// Closes the PiP window, notifies the main isolate to turn off the setting, and hides the native window.
  void _closeWindow() {
    IpcBridge.instance.sendEvent('companion.close');
    NativeBridge.hidePipWindow();
  }

  /// Collapses the bar to show only the expand arrow, or restores it.
  ///
  /// Animation duration: 200 ms (Req 16.3).
  void _toggleBar() {
    setState(() => _barExpanded = !_barExpanded);
    if (_barExpanded) {
      _barAnim.forward();
    } else {
      _barAnim.reverse();
    }
  }

  // ── Feedback toast ──────────────────────────────────────────────────────

  void _flashFeedback(String text) {
    setState(() => _feedbackText = text);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _feedbackText = null);
    });
  }

  // ── Pet-area gesture handlers (Task 9.2) ─────────────────────────────────

  /// The drag-handle height in logical pixels (Req 1.4, 5.7).
  static const double _dragHandleHeight = CompanionWindowManager.handleHeight;

  void _onPetTap() {
    _interactionController.onPetClicked();
  }

  void _onPetDoubleTap() {
    _interactionController.onPetDoubleClicked();
  }

  void _onDragStart(DragStartDetails details) {
    _dragStartPosition = details.globalPosition;
    _lastDragPosition = details.globalPosition;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final start = _dragStartPosition;
    if (start == null) return;

    // Ignore drag updates that originated in the drag handle (Req 5.7).
    // We compare the start local-Y against the drag handle height.
    // details.localPosition is relative to the GestureDetector, which wraps
    // the full window minus the drag handle (see build()), so the start will
    // always be below the drag handle.  Guard is kept here for clarity.
    final delta = details.globalPosition - (_lastDragPosition ?? start);
    _lastDragPosition = details.globalPosition;
    _interactionController.onPetDragged(delta);
  }

  void _onDragEnd(DragEndDetails details) {
    final start = _dragStartPosition;
    final last = _lastDragPosition;
    if (start != null && last != null) {
      final dragVector = last - start;
      _interactionController.onPetDragReleased(dragVector);
    }
    _dragStartPosition = null;
    _lastDragPosition = null;
  }

  void _onHover(PointerHoverEvent event) {
    // Route mouse-move events to petting logic.  Velocity is read internally
    // by InteractionController from CursorTracker (Req 6.1, 6.8).
    _interactionController.onPetPetted();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  bool get _isLightBackground => _pipBackgroundStyle == 'light';

  Decoration _buildContainerDecoration() {
    if (_pipBackgroundStyle == 'transparent') {
      return const BoxDecoration(color: Colors.transparent);
    }

    if (_pipBackgroundStyle == 'light') {
      return BoxDecoration(
        color: const Color(
          0xFFF5F5FA,
        ).withValues(alpha: 0.75), // Translucent frosted light theme
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF161622).withValues(alpha: 0.12),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      );
    }

    // default: 'dark'
    return BoxDecoration(
      color: const Color(
        0xFF161622,
      ).withValues(alpha: 0.75), // Translucent dark theme
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.12),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 10,
          spreadRadius: 1,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = _isLightBackground;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        margin: const EdgeInsets.all(8.0),
        decoration: _buildContainerDecoration(),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // ── Flame game fills the card ─────────────────────────────
            if (_gameInitialized && _game != null)
              Positioned.fill(child: GameWidget(game: _game!))
            else
              const Positioned.fill(
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Colors.white38,
                  ),
                ),
              ),

            // ── Top 24 px drag handle (Task 9.3) ──────────────────────────────
            // Positioned above the pet area. Routes pan gestures to native
            // window-drag. Always interactive — excluded from clickThrough
            // pass-through (Req 1.4, 1.5, 1.6).
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: _dragHandleHeight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => _windowManager.startDrag(),
                child: Center(
                  child: Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isLight
                          ? const Color(0xFF161622).withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),

            // ── Floating pet name badge (below drag handle) ────────────────────
            Positioned(
              top: _dragHandleHeight,
              left: 0,
              right: 0,
              child: Center(
                child: _PetNameBadge(
                  name: _petName,
                  isLightBackground: isLight,
                ),
              ),
            ),

            // ── Pet-area gesture detector (Task 9.2) ──────────────────────────
            // Covers the full window except the drag handle at top and the
            // interaction bar at bottom.  Excluded from clickThrough (Req 1.6).
            Positioned(
              top: _dragHandleHeight,
              left: 0,
              right: 0,
              bottom: _kInteractionBarHeight,
              child: Listener(
                onPointerHover: _onHover,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _onPetTap,
                  onDoubleTap: _onPetDoubleTap,
                  onPanStart: _onDragStart,
                  onPanUpdate: _onDragUpdate,
                  onPanEnd: _onDragEnd,
                ),
              ),
            ),

            // ── Floating feedback toast ────────────────────────────────────────
            if (_feedbackText != null)
              Positioned(
                top: _dragHandleHeight + 8,
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

            // ── Interaction bar at bottom (Task 9.1) ──────────────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _InteractionBar(
                expandFraction: _barWidth,
                isExpanded: _barExpanded,
                throwDisabled: _throwDisabled,
                treatOnCooldown: _treatOnCooldown,
                toyEmoji: _getToyEmoji(),
                treatEmoji: _getTreatEmoji(),
                onThrowBall: _throwBall,
                onGiveTreat: _giveTreat,
                onToggleCollapse: _toggleBar,
                isLightBackground: isLight,
              ),
            ),

            // ── Top-Right Close Button ──────────────────────────────────────
            Positioned(
              top: 12,
              right: 12,
              child: _CloseButton(
                onTap: _closeWindow,
                isLightBackground: isLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Maximum height of the interaction bar region (used for pet-area layout).
const double _kInteractionBarHeight = 44.0;

// ─────────────────────────────────────────────────────────────────────────────
// _PetNameBadge
// ─────────────────────────────────────────────────────────────────────────────

class _PetNameBadge extends StatelessWidget {
  const _PetNameBadge({required this.name, required this.isLightBackground});
  final String name;
  final bool isLightBackground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isLightBackground
            ? const Color(0xFFE6E6F0).withValues(alpha: 0.8)
            : const Color(0xFF1E1E2E).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLightBackground
              ? const Color(0xFF161622).withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.12),
          width: 1.0,
        ),
      ),
      child: Text(
        name,
        style: TextStyle(
          color: isLightBackground ? const Color(0xFF161622) : Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          fontFamily: 'Inter',
          letterSpacing: 0.5,
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
// _InteractionBar  (Task 9.1 — upgraded widget, Req 16.1–16.8)
//
// Layout:
//   [🎾 Throw] [🍣 Treat] [👁 Quiet] [‹ Collapse arrow]
//
// Height: constrained to ≤ 44 logical pixels.
// Each tap target: ≥ 36×36 logical pixels.
//
// Collapse animation: the three action buttons fade+slide away in 200 ms,
// leaving only the expand arrow (Req 16.3).
// ─────────────────────────────────────────────────────────────────────────────

class _InteractionBar extends StatelessWidget {
  const _InteractionBar({
    required this.expandFraction,
    required this.isExpanded,
    required this.throwDisabled,
    required this.treatOnCooldown,
    required this.toyEmoji,
    required this.treatEmoji,
    required this.onThrowBall,
    required this.onGiveTreat,
    required this.onToggleCollapse,
    required this.isLightBackground,
  });

  /// Animation value in [0, 1] that drives the collapsible section width.
  final Animation<double> expandFraction;

  final bool isExpanded;
  final bool throwDisabled;
  final bool treatOnCooldown;
  final String toyEmoji;
  final String treatEmoji;

  final VoidCallback onThrowBall;
  final VoidCallback onGiveTreat;
  final VoidCallback onToggleCollapse;
  final bool isLightBackground;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: _kInteractionBarHeight),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isLightBackground
            ? const Color(0xFFF5F5FA).withValues(alpha: 0.9)
            : const Color(
                0xFF161622,
              ).withValues(alpha: 0.8), // Sleek translucent bar
        border: Border(
          top: BorderSide(
            color: isLightBackground
                ? const Color(0xFF161622).withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.1),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // ── Collapsible action buttons (animate width → 0 on collapse) ──
          AnimatedBuilder(
            animation: expandFraction,
            builder: (context, child) {
              return ClipRect(
                child: Align(
                  widthFactor: expandFraction.value,
                  alignment: Alignment.centerRight,
                  child: child,
                ),
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🎾 Throw ball (Req 16.1, 16.4)
                _BarButton(
                  emoji: toyEmoji,
                  label: 'Throw',
                  disabled: throwDisabled,
                  onTap: onThrowBall,
                  isLightBackground: isLightBackground,
                ),
                const SizedBox(width: 6),
                // 🍣 Give treat (Req 16.1, 16.5)
                _BarButton(
                  emoji: treatEmoji,
                  label: 'Treat',
                  disabled: treatOnCooldown,
                  onTap: onGiveTreat,
                  isLightBackground: isLightBackground,
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),

          // ── Collapse / expand arrow (always visible, Req 16.7) ──────────
          // Req 16.8: tap target ≥ 36×36.
          GestureDetector(
            onTap: onToggleCollapse,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 36,
              height: 36,
              child: Center(
                child: AnimatedRotation(
                  turns: isExpanded ? 0.0 : 0.5,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_right_rounded,
                    color: isLightBackground
                        ? const Color(0xFF161622).withValues(alpha: 0.8)
                        : Colors.white70,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CloseButton — circular Apple-style hover-animated close button
// ─────────────────────────────────────────────────────────────────────────────

class _CloseButton extends StatefulWidget {
  const _CloseButton({required this.onTap, required this.isLightBackground});
  final VoidCallback onTap;
  final bool isLightBackground;

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: _isHovered
                    ? const Color(0xFFFF5F56)
                    : (widget.isLightBackground
                          ? const Color(0xFF161622).withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.15)),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isHovered
                      ? const Color(0xFFE0443E)
                      : (widget.isLightBackground
                            ? const Color(0xFF161622).withValues(alpha: 0.1)
                            : Colors.white.withValues(alpha: 0.1)),
                  width: 1.0,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.close_rounded,
                  size: 12,
                  color: _isHovered
                      ? Colors.white
                      : (widget.isLightBackground
                            ? const Color(0xFF161622).withValues(alpha: 0.8)
                            : Colors.white70),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _BarButton — single icon+label button in the InteractionBar
//
// Req 16.2: tap target ≥ 36×36 logical pixels.
// Disabled state: opacity 0.4, taps suppressed (Req 16.4, 16.5).
// ─────────────────────────────────────────────────────────────────────────────

class _BarButton extends StatefulWidget {
  const _BarButton({
    required this.emoji,
    required this.label,
    required this.disabled,
    required this.onTap,
    required this.isLightBackground,
  });

  final String emoji;
  final String label;
  final bool disabled;
  final VoidCallback onTap;
  final bool isLightBackground;

  @override
  State<_BarButton> createState() => _BarButtonState();
}

class _BarButtonState extends State<_BarButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _scale;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.85,
    ).animate(CurvedAnimation(parent: _press, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.disabled) return; // Req 16.4, 16.5: suppress taps when disabled
    _press.forward().then((_) => _press.reverse());
    widget.onTap();
  }

  Color _getGlowColor() {
    if (widget.emoji == '🎾') return const Color(0xFFCCFF00);
    if (widget.emoji == '🍣') return const Color(0xFFFF5E5B);
    return const Color(0xFF5F68E9);
  }

  @override
  Widget build(BuildContext context) {
    final glowColor = _getGlowColor();
    final bool isHoverActive = _isHovered && !widget.disabled;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          // Req 16.4 / 16.5: 0.4 opacity when disabled, 1.0 when enabled.
          opacity: widget.disabled ? 0.4 : 1.0,
          child: ScaleTransition(
            scale: _scale,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 44,
              height: 36,
              decoration: BoxDecoration(
                color: isHoverActive
                    ? glowColor.withValues(alpha: 0.18)
                    : (widget.isLightBackground
                          ? const Color(0xFF161622).withValues(alpha: 0.05)
                          : Colors.white.withValues(alpha: 0.05)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isHoverActive
                      ? glowColor.withValues(alpha: 0.35)
                      : (widget.isLightBackground
                            ? const Color(0xFF161622).withValues(alpha: 0.1)
                            : Colors.white.withValues(alpha: 0.1)),
                  width: 1.0,
                ),
                boxShadow: isHoverActive
                    ? [
                        BoxShadow(
                          color: glowColor.withValues(alpha: 0.25),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedScale(
                    scale: isHoverActive ? 1.15 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: Text(
                      widget.emoji,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: isHoverActive
                          ? (widget.isLightBackground
                                ? const Color(0xFF161622)
                                : Colors.white)
                          : (widget.isLightBackground
                                ? const Color(0xFF161622).withValues(alpha: 0.7)
                                : Colors.white70),
                      fontSize: 8,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
