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
import 'package:breakmate/core/ipc/ipc_events.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/flame/companion_game.dart';
import 'package:breakmate/features/companion/interaction/interaction_controller.dart';
import 'package:breakmate/features/companion/services/companion_window_manager.dart';
import 'package:breakmate/features/companion/services/display_manager.dart';

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
  double _scale = 3.0;
  bool _gameInitialized = false;

  late final CompanionWindowManager _windowManager = CompanionWindowManager(
    displayManager: NativeDisplayManager(),
  );
  final InteractionController _interactionController = InteractionController();

  bool _clickThrough = false;
  bool _acceptsMouse = true;
  Timer? _clickThroughTimer;

  bool _barExpanded = true;

  late final AnimationController _barAnim;
  late final Animation<double> _barWidth;

  bool _throwDisabled = false;

  StreamSubscription<AppEvent>? _throwEventSub;

  bool _treatOnCooldown = false;
  Timer? _treatCooldownTimer;

  StreamSubscription<AppEvent>? _treatEventSub;

  String _pipBackgroundStyle = 'dark';
  double _pipOpacity = 0.9;
  bool _pipDraggableClickable = true;

  Offset? _dragStartPosition;

  Offset? _lastDragPosition;

  String? _feedbackText;

  @override
  void initState() {
    super.initState();

    _barAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1.0,
    );
    _barWidth = _barAnim;

    _channel.setMethodCallHandler(_handleMethodCall);
    _fetchInitialSettings();
    _interactionController.initialize();

    _clickThroughTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _checkClickThrough();
    });

    _throwEventSub = EventBus.instance.stream.listen(_handleThrowEvent);
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

  void _handleThrowEvent(AppEvent event) {
    if (!mounted) return;

    if (event is ThrowableSpawnedEvent || event is ThrowableDisposedEvent) {
      if (event is ThrowableDisposedEvent) {
        if (_throwDisabled) setState(() => _throwDisabled = false);
      }
    }

    if (event is ThrowRejectedEvent) {
      if (!_throwDisabled) setState(() => _throwDisabled = true);
    }
  }

  void _handleTreatEvent(AppEvent event) {
    if (!mounted) return;
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'syncPiPSettings':
        final args = call.arguments as Map<dynamic, dynamic>?;
        if (args != null) _applySettings(Map<String, dynamic>.from(args));
        break;
      case 'toggleButtons':
        _toggleBar();
        break;
    }
  }

  Future<void> _fetchInitialSettings() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getInitialSettings',
      );
      if (result != null) {
        _applySettings(Map<String, dynamic>.from(result));
        await _windowManager.initialize();
        return;
      }
    } catch (_) {
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
        top = primaryScreenHeight - pos.dy - size.height;
      }

      final windowRect = Rect.fromLTWH(pos.dx, top, size.width, size.height);

      bool accepts = true;
      if (windowRect.contains(cursorPos)) {
        final localX = cursorPos.dx - windowRect.left;
        final localY = cursorPos.dy - windowRect.top;

        final inCard =
            localX >= 8.0 &&
            localX <= (size.width - 8.0) &&
            localY >= 8.0 &&
            localY <= (size.height - 8.0);

        if (inCard) {
          final inDragHandle = localY >= 8.0 && localY <= 32.0;
          final inInteractionBar =
              localY >= (size.height - 8.0 - 44.0) &&
              localY <= (size.height - 8.0);
          accepts = inDragHandle || inInteractionBar;
        } else {
          accepts = false;
        }
      } else {
        accepts = true;
      }

      if (_acceptsMouse != accepts) {
        _acceptsMouse = accepts;
        await _windowManager.setAcceptsMouse(accepts);
      }
    } catch (e) {
      throw Exception(e);
    }
  }

  String _getToyIconPath() {
    switch (_game?.toyType) {
      case 'toy_mouse':
        return 'assets/ui/icons/mouse_sheet.png';
      case 'pink_yarn':
        return 'assets/ui/icons/pinkball_sheet.png';
      case 'orange_yarn':
        return 'assets/ui/icons/orangeball_sheet.png';
      case 'tennis_ball':
      default:
        return 'assets/animations/throw_particles/tennis-ball.png';
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

  void _throwBall() {
    if (_throwDisabled) return;
    _interactionController.throwToy();
    _flashFeedback('Fetch!');
  }

  void _giveTreat() {
    if (_treatOnCooldown) return;
    _interactionController.giveTreat();
    _flashFeedback('Treat!');

    setState(() => _treatOnCooldown = true);
    _treatCooldownTimer?.cancel();
    _treatCooldownTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) setState(() => _treatOnCooldown = false);
    });
  }

  void _closeWindow() {
    IpcBridge.instance.dispatch(CompanionCloseIpcEvent());
    NativeBridge.hidePipWindow();
  }

  void _toggleBar() {
    setState(() => _barExpanded = !_barExpanded);
    if (_barExpanded) {
      _barAnim.forward();
    } else {
      _barAnim.reverse();
    }
  }

  void _flashFeedback(String text) {
    setState(() => _feedbackText = text);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _feedbackText = null);
    });
  }

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
    _interactionController.onPetPetted();
  }

  bool get _isLightBackground => _pipBackgroundStyle == 'light';

  Decoration _buildContainerDecoration() {
    if (_pipBackgroundStyle == 'transparent') {
      return const BoxDecoration(color: Colors.transparent);
    }

    if (_pipBackgroundStyle == 'light') {
      return BoxDecoration(
        color: const Color(0xFFF5F5FA).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF161622).withValues(alpha: 0.1),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      );
    }

    return BoxDecoration(
      color: const Color(0xFF161622).withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.1),
        width: 1.0,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 16,
          spreadRadius: 2,
          offset: const Offset(0, 8),
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
        margin: const EdgeInsets.all(12.0),
        decoration: _buildContainerDecoration(),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
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
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isLight
                          ? const Color(0xFF161622).withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              top: 14,
              left: 0,
              right: 0,
              child: Center(
                child: _PetNameBadge(
                  name: _petName,
                  isLightBackground: isLight,
                ),
              ),
            ),

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

            if (_feedbackText != null)
              Positioned(
                top: 50,
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

            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _InteractionBar(
                expandFraction: _barWidth,
                isExpanded: _barExpanded,
                throwDisabled: _throwDisabled,
                treatOnCooldown: _treatOnCooldown,
                toyIconPath: _getToyIconPath(),
                treatEmoji: _getTreatEmoji(),
                onThrowBall: _throwBall,
                onGiveTreat: _giveTreat,
                onToggleCollapse: _toggleBar,
                isLightBackground: isLight,
              ),
            ),

            Positioned(
              top: 10,
              right: 10,
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

const double _kInteractionBarHeight = 52.0;

class _PetNameBadge extends StatelessWidget {
  const _PetNameBadge({required this.name, required this.isLightBackground});
  final String name;
  final bool isLightBackground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isLightBackground
            ? const Color(0xFFE6E6F0).withValues(alpha: 0.9)
            : const Color(0xFF2D2D3E).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        name,
        style: TextStyle(
          color: isLightBackground ? const Color(0xFF161622) : Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter',
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _FeedbackToast extends StatelessWidget {
  const _FeedbackToast({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161622).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}

class _InteractionBar extends StatelessWidget {
  const _InteractionBar({
    required this.expandFraction,
    required this.isExpanded,
    required this.throwDisabled,
    required this.treatOnCooldown,
    required this.toyIconPath,
    required this.treatEmoji,
    required this.onThrowBall,
    required this.onGiveTreat,
    required this.onToggleCollapse,
    required this.isLightBackground,
  });

  final Animation<double> expandFraction;
  final bool isExpanded;
  final bool throwDisabled;
  final bool treatOnCooldown;
  final String toyIconPath;
  final String treatEmoji;
  final VoidCallback onThrowBall;
  final VoidCallback onGiveTreat;
  final VoidCallback onToggleCollapse;
  final bool isLightBackground;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _kInteractionBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isLightBackground
            ? const Color(0xFFF5F5FA).withValues(alpha: 0.5)
            : const Color(0xFF161622).withValues(alpha: 0.4),
        border: Border(
          top: BorderSide(
            color: isLightBackground
                ? const Color(0xFF161622).withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.05),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: expandFraction,
            builder: (context, child) {
              return ClipRect(
                child: Align(
                  widthFactor: expandFraction.value,
                  alignment: Alignment.center,
                  child: child,
                ),
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _BarButton(
                  iconPath: toyIconPath,
                  label: 'Throw',
                  disabled: throwDisabled,
                  onTap: onThrowBall,
                  isLightBackground: isLightBackground,
                ),
                const SizedBox(width: 12),
                _BarButton(
                  emoji: treatEmoji,
                  label: 'Treat',
                  disabled: treatOnCooldown,
                  onTap: onGiveTreat,
                  isLightBackground: isLightBackground,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onToggleCollapse,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isLightBackground
                    ? Colors.black.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: AnimatedRotation(
                  turns: isExpanded ? 0.0 : 0.5,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_right_rounded,
                    color: isLightBackground
                        ? const Color(0xFF161622)
                        : Colors.white70,
                    size: 20,
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _isHovered
                ? const Color(0xFFE0443E).withValues(alpha: 0.9)
                : (widget.isLightBackground
                      ? Colors.black.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.12)),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              Icons.close_rounded,
              size: 14,
              color: _isHovered
                  ? Colors.white
                  : (widget.isLightBackground
                        ? const Color(0xFF161622)
                        : Colors.white70),
            ),
          ),
        ),
      ),
    );
  }
}

class _BarButton extends StatefulWidget {
  const _BarButton({
    this.emoji,
    this.iconPath,
    required this.label,
    required this.disabled,
    required this.onTap,
    required this.isLightBackground,
  }) : assert(emoji != null || iconPath != null);

  final String? emoji;
  final String? iconPath;
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
      end: 0.92,
    ).animate(CurvedAnimation(parent: _press, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.disabled) return;
    _press.forward().then((_) => _press.reverse());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final bool isHoverActive = _isHovered && !widget.disabled;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: widget.disabled ? 0.4 : 1.0,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isHoverActive
                        ? (widget.isLightBackground
                              ? Colors.black.withValues(alpha: 0.1)
                              : Colors.white.withValues(alpha: 0.1))
                        : (widget.isLightBackground
                              ? Colors.black.withValues(alpha: 0.05)
                              : Colors.white.withValues(alpha: 0.05)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isHoverActive
                          ? (widget.isLightBackground
                                ? Colors.black.withValues(alpha: 0.1)
                                : Colors.white.withValues(alpha: 0.1))
                          : Colors.transparent,
                      width: 1.0,
                    ),
                  ),
                  child: Center(
                    child: widget.iconPath != null
                        ? Image.asset(
                            widget.iconPath!,
                            width: 22,
                            height: 22,
                            fit: BoxFit.contain,
                          )
                        : Text(
                            widget.emoji!,
                            style: const TextStyle(fontSize: 18),
                          ),
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: widget.isLightBackground
                          ? const Color(0xFF161622)
                          : Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
