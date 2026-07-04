import 'dart:async';

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
import 'package:breakmate/features/companion/domain/pet_state_machine.dart';
import 'package:breakmate/features/companion/flame/companion_game.dart';
import 'package:breakmate/features/companion/interaction/interaction_controller.dart';
import 'package:breakmate/features/companion/services/companion_window_manager.dart';
import 'package:breakmate/features/companion/services/display_manager.dart';
import 'package:breakmate/core/errors/error_handler.dart';
import 'package:breakmate/core/errors/app_exception.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/features/companion/services/custom_environment_repository.dart';
import 'package:breakmate/core/services/simple_prefs.dart';

import 'package:breakmate/core/ipc/overlay_config.dart';

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
  late String _themeId = SimplePrefs.instance.getString(
    'companion_pet_theme',
    defaultValue: 'grey_cat',
  );
  String _petName = 'Mochi';
  late double _scale = SimplePrefs.instance.getDouble(
    'companion_scale',
    defaultValue: 3.0,
  );
  bool _gameInitialized = false;
  late String _previewBackground = SimplePrefs.instance.getString(
    'companion_preview_background',
    defaultValue: 'assets/background/forest/background.png',
  );

  late final CompanionWindowManager _windowManager = CompanionWindowManager(
    displayManager: NativeDisplayManager(),
  );
  InteractionController? _interactionController;

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

  late String _pipBackgroundStyle = SimplePrefs.instance.getString(
    'pip_background_style',
    defaultValue: 'dark',
  );
  late double _pipOpacity = SimplePrefs.instance.getDouble(
    'pip_opacity',
    defaultValue: 1.0,
  );
  late bool _pipDraggableClickable = SimplePrefs.instance.getBool(
    'pip_draggable_clickable',
    defaultValue: true,
  );

  Offset? _dragStartPosition;
  Offset? _lastDragPosition;
  Offset? _lastLocalDragPosition;

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
    _interactionController?.dispose();
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
        if (args != null) _applySettings(OverlayConfig.fromJson(Map<String, dynamic>.from(args)));
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
        _applySettings(OverlayConfig.fromJson(Map<String, dynamic>.from(result)));
        await _windowManager.initialize();
        return;
      }
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }
    _initGameWithDefaults();
    await _windowManager.initialize();
  }

  void _initGameWithDefaults() {
    if (!mounted || _gameInitialized) return;
    final toyType = SimplePrefs.instance.getString(
      'companion_toy_type',
      defaultValue: 'tennis_ball',
    );
    final treatType = SimplePrefs.instance.getString(
      'companion_treat_type',
      defaultValue: 'sushi',
    );
    setState(() {
      _game = CompanionGame(
        initialTheme: PetTheme.getTheme(_themeId),
        scaleOverride: _scale,
        isPiP: true,
        toyType: toyType,
        treatType: treatType,
        backgroundImagePath: _previewBackground,
      );
      _gameInitialized = true;
      _interactionController?.dispose();
      _interactionController = InteractionController(
        throwableObjectManager: _game!.throwableManager,
        petCompanionService: _game!.petService,
        needsEngine: _game!.needsEngine,
        settingsRepository: sl.isRegistered<SettingsRepository>()
            ? sl<SettingsRepository>()
            : null,
        isPiP: true,
      );
      _interactionController!.initialize();
    });
  }

  void _applySettings(OverlayConfig config) {
    if (!mounted) return;

    try {
      CustomEnvironmentRepository().loadSync();
    } catch (_) {}

    final newThemeId = config.themeId ?? _themeId;
    final newScale = config.scale ?? _scale;
    final newPetName = config.petName ?? _petName;
    final newClickThrough = config.clickThrough ?? _clickThrough;
    final newPipBackgroundStyle =
        config.pipBackgroundStyle ?? _pipBackgroundStyle;
    final newPipOpacity =
        config.pipOpacity ?? _pipOpacity;
    final newPipDraggableClickable =
        config.pipDraggableClickable ?? _pipDraggableClickable;
    final newToyType = config.companionToyType ?? 'tennis_ball';
    final newTreatType = config.companionTreatType ?? 'sushi';
    final newPreviewBackground =
        config.previewBackground ?? _previewBackground;
    final newWanderingEnabled = config.wanderingEnabled ?? true;

    if (!_gameInitialized) {
      setState(() {
        _themeId = newThemeId;
        _scale = newScale > 0 ? newScale : 3.0;
        _petName = newPetName;
        _clickThrough = newClickThrough;
        _pipBackgroundStyle = newPipBackgroundStyle;
        _pipOpacity = newPipOpacity;
        _pipDraggableClickable = newPipDraggableClickable;
        _previewBackground = newPreviewBackground;
        _game = CompanionGame(
          initialTheme: PetTheme.getTheme(_themeId),
          scaleOverride: _scale,
          isPiP: true,
          toyType: newToyType,
          treatType: newTreatType,
          backgroundImagePath: newPreviewBackground,
        );
        _gameInitialized = true;
        _interactionController?.dispose();
        _interactionController = InteractionController(
          throwableObjectManager: _game!.throwableManager,
          petCompanionService: _game!.petService,
          needsEngine: _game!.needsEngine,
          settingsRepository: sl.isRegistered<SettingsRepository>()
              ? sl<SettingsRepository>()
              : null,
          isPiP: true,
        );
        _interactionController!.initialize();
      });
      _game?.setWanderingEnabled(newWanderingEnabled);
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
        if (newPreviewBackground != _previewBackground) {
          _previewBackground = newPreviewBackground;
          _game?.updateBackgroundImagePath(newPreviewBackground);
        } else {
          _game?.reloadEnvironment();
        }
        _pipBackgroundStyle = newPipBackgroundStyle;
        _pipOpacity = newPipOpacity;
        _pipDraggableClickable = newPipDraggableClickable;
      });
      _game?.setWanderingEnabled(newWanderingEnabled);
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

      final windowRect = Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height);

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
          final inCloseButton =
              localX >= (size.width - 60.0) &&
              localX <= (size.width - 24.0) &&
              localY >= 24.0 &&
              localY <= 60.0;
          accepts = inDragHandle || inInteractionBar || inCloseButton;
        } else {
          // If the mouse is in the outer 8px margin (resize border),
          // we must accept mouse events so that resizing can occur.
          accepts = true;
        }
      } else {
        accepts = true;
      }

      if (_acceptsMouse != accepts) {
        _acceptsMouse = accepts;
        await _windowManager.setAcceptsMouse(accepts);
      }
    } catch (e, st) {
      throw AppException(
        type: AppErrorType.ui,
        message: 'PiP click-through check failed: ${e.toString()}',
        originalError: e,
        stackTrace: st,
      );
    }
  }

  String? _getToyIconPath() {
    switch (_game?.toyType) {
      case 'base_ball':
        return 'assets/animations/throw_particles/base_ball.png';
      case 'basket_ball':
        return 'assets/animations/throw_particles/basket_ball.png';
      case 'football':
        return 'assets/animations/throw_particles/football.png';
      case 'bone':
      case 'sushi':
      case 'carrot':
        return null;
      case 'tennis_ball':
      default:
        return 'assets/animations/throw_particles/tennis_ball.png';
    }
  }

  String? _getToyEmoji() {
    switch (_game?.toyType) {
      case 'bone':
        return '🦴';
      case 'sushi':
        return '🍣';
      case 'carrot':
        return '🥕';
      default:
        return null;
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
    _interactionController?.throwToy();
    _flashFeedback('Fetch!');
  }

  void _giveTreat() {
    if (_treatOnCooldown) return;
    _interactionController?.giveTreat();
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

  void _handleTapUp(Offset localPos) {
    if (_game == null || !_gameInitialized) return;

    final gameX = localPos.dx;
    final gameY = localPos.dy + _dragHandleHeight;

    final pet = _game!.petComponent;
    if (pet != null) {
      final petX = pet.position.x;
      final petY = pet.position.y;
      final petW = pet.size.x * pet.scale.x.abs();
      final petH = pet.size.y * pet.scale.y.abs();

      // Since the anchor is Anchor.bottomCenter:
      final left = petX - petW / 2;
      final right = petX + petW / 2;
      final top = petY - petH;
      final bottom = petY;

      if (gameX >= left && gameX <= right && gameY >= top && gameY <= bottom) {
        _onPetTap();
        return;
      }
    }

    // Tapped on the background -> move the pet to the horizontal coordinate
    final targetY = pet?.position.y ?? gameY;
    _game!.petService.navigation.setTarget(Offset(gameX, targetY));
    _game!.petService.stateMachine.transitionTo(PetState.walk);
  }

  void _onPetTap() {
    _interactionController?.onPetClicked();
  }

  void _onPetDoubleTap() {
    _interactionController?.onPetDoubleClicked();
  }

  void _onDragStart(DragStartDetails details) {
    _dragStartPosition = details.globalPosition;
    _lastDragPosition = details.globalPosition;
    _lastLocalDragPosition = details.localPosition;

    final worldPos = _game?.screenToWorld(details.localPosition);
    if (worldPos != null) {
      _game?.onDragStart(worldPos);
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final start = _dragStartPosition;
    if (start == null) return;

    final delta = details.globalPosition - (_lastDragPosition ?? start);
    _lastDragPosition = details.globalPosition;
    _lastLocalDragPosition = details.localPosition;
    _interactionController?.onPetDragged(delta);
  }

  void _onDragEnd(DragEndDetails details) {
    final start = _dragStartPosition;
    final last = _lastDragPosition;
    if (start != null && last != null) {
      _interactionController?.onPetDragReleased(Offset.zero);
    }

    final lastLocal = _lastLocalDragPosition;
    if (lastLocal != null) {
      final worldPos = _game?.screenToWorld(lastLocal);
      if (worldPos != null) {
        _game?.onDragEnd(worldPos);
      }
    }

    _dragStartPosition = null;
    _lastDragPosition = null;
    _lastLocalDragPosition = null;
  }

  void _onHover(PointerHoverEvent event) {
    _interactionController?.onPetPetted();
  }

  bool get _isLightBackground => _pipBackgroundStyle == 'light';

  Decoration _buildContainerDecoration() {
    if (_pipBackgroundStyle == 'light') {
      return BoxDecoration(
        color: const Color(0xFFF5F5FA),
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
      color: const Color(0xFF161622),
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
      body: Opacity(
        opacity: _pipOpacity,
        child: Container(
          margin: const EdgeInsets.all(12.0),
          decoration: _buildContainerDecoration(),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Expanded(
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
                                  ? const Color(
                                      0xFF161622,
                                    ).withValues(alpha: 0.15)
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
                          onTapUp: (details) =>
                              _handleTapUp(details.localPosition),
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
                      top: 16,
                      right: 16,
                      child: _CloseButton(
                        onTap: _closeWindow,
                        isLightBackground: isLight,
                      ),
                    ),
                  ],
                ),
              ),
              _InteractionBar(
                expandFraction: _barWidth,
                isExpanded: _barExpanded,
                throwDisabled: _throwDisabled,
                treatOnCooldown: _treatOnCooldown,
                toyIconPath: _getToyIconPath(),
                toyEmoji: _getToyEmoji(),
                treatEmoji: _getTreatEmoji(),
                onThrowBall: _throwBall,
                onGiveTreat: _giveTreat,
                onToggleCollapse: _toggleBar,
                isLightBackground: isLight,
              ),
            ],
          ),
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
    this.toyIconPath,
    this.toyEmoji,
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
  final String? toyIconPath;
  final String? toyEmoji;
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
                  emoji: toyEmoji,
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
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isHoverActive
                        ? (widget.isLightBackground
                              ? Colors.black.withValues(alpha: 0.1)
                              : Colors.white.withValues(alpha: 0.1))
                        : (widget.isLightBackground
                              ? Colors.black.withValues(alpha: 0.05)
                              : Colors.white.withValues(alpha: 0.05)),
                    borderRadius: BorderRadius.circular(10),
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
                            width: 18,
                            height: 18,
                            fit: BoxFit.contain,
                          )
                        : Text(
                            widget.emoji!,
                            style: const TextStyle(fontSize: 15),
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
