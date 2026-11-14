import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:breakmate/core/ipc/ipc_maps.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'package:breakmate/core/errors/error_handler.dart';
import 'package:breakmate/core/ipc/ipc_bridge.dart';
import 'package:breakmate/core/ipc/ipc_events.dart';
import 'package:breakmate/core/ipc/overlay_config.dart';
import 'package:breakmate/core/native/native_bridge.dart';
import 'package:breakmate/core/services/simple_prefs.dart';
import 'package:breakmate/features/companion/behavior/companion_mood_machine.dart';
import 'package:breakmate/features/companion/behavior/cursor_feed.dart';
import 'package:breakmate/features/companion/behavior/gaze_sector.dart';
import 'package:breakmate/features/companion/behavior/pet_behavior_engine.dart';
import 'package:breakmate/features/companion/behavior/pet_emotion.dart';
import 'package:breakmate/features/companion/behavior/pet_wanderer.dart';
import 'package:breakmate/features/companion/domain/avatar_definition.dart';
import 'package:breakmate/features/companion/domain/avatar_species.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/overlay/mouse_hit_policy.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_3d_view.dart';
import 'package:breakmate/features/companion/presentation/widgets/pet_interaction_effect.dart';
import 'package:breakmate/features/companion/presentation/widgets/pet_stage.dart';
import 'package:breakmate/features/companion/render/avatar_artwork.dart';
import 'package:breakmate/features/companion/render/avatar_artwork_loader.dart';
import 'package:breakmate/features/companion/render/avatar_artwork_recipe.dart';
import 'package:breakmate/features/companion/services/companion_window_manager.dart';
import 'package:breakmate/features/companion/services/display_manager.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/shared/utils/reduced_motion.dart';

part 'pip_overlay_widgets.dart';

/// Root widget of the separate PiP companion window process: renders the avatar, runs the behavior engine/wanderer and talks to the main app over the pip_data channel.
class PiPOverlayWindow extends StatefulWidget {
  const PiPOverlayWindow({super.key});

  @override
  State<PiPOverlayWindow> createState() => _PiPOverlayWindowState();
}

class _PiPOverlayWindowState extends State<PiPOverlayWindow>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const MethodChannel _channel = MethodChannel(
    'com.breakmate.desktop/pip_data',
  );

  static const Duration _viewportSyncInterval = Duration(milliseconds: 400);

  static const Duration _restInterval = Duration(milliseconds: 250);

  late final PetBehaviorEngine _engine = PetBehaviorEngine(
    reducedMotion: prefersReducedMotion,
  );
  late final Ticker _ticker = createTicker(_tickEngine);

  final Stopwatch _clock = Stopwatch()..start();
  Timer? _restTimer;
  final List<Timer> _hopTimers = <Timer>[];
  PetInteractionKind? _effectKind;
  int _effectSeq = 0;
  StreamSubscription<CursorSample>? _cursorSub;
  Timer? _viewportTimer;
  Duration _lastFrameElapsed = Duration.zero;
  bool _windowVisible = true;

  late final CompanionWindowManager _windowManager = CompanionWindowManager(
    displayManager: NativeDisplayManager(),
  );

  late final PetWanderer _wanderer = PetWanderer.forWindow(
    windowManager: _windowManager,
    engine: _engine,

    onArrived: _syncViewport,
  );

  late String _themeId = SimplePrefs.instance.getString(
    'companion_pet_theme',
    defaultValue: 'avatar_cat',
  );
  String _petName = 'Lily';
  AvatarDefinition? _definition;
  String? _renderMode;

  late double _pipOpacity = SimplePrefs.instance.getDouble(
    'pip_opacity',
    defaultValue: 1.0,
  );
  late double _scale = SimplePrefs.instance.getDouble(
    'companion_scale',
    defaultValue: 6.0,
  );
  late bool _pipDraggableClickable = SimplePrefs.instance.getBool(
    'pip_draggable_clickable',
    defaultValue: true,
  );
  late bool _keepOnScreen = SimplePrefs.instance.getBool(
    'companion_keep_on_screen',
    defaultValue: true,
  );

  late String _backdrop = SimplePrefs.instance.getString(
    'pip_background_style',
    defaultValue: 'scene',
  );
  bool _clickThrough = false;

  bool _pettingEnabled = true;
  bool _playEnabled = true;
  bool _treatEnabled = true;

  bool _gazeEnabled = true;
  double _gazeSensitivity = 0.5;
  bool _idleAnimation = true;
  bool _reactions = true;
  bool _reducedMotionSetting = false;
  bool _animationsEnabled = true;
  bool _wanderingRequested = false;

  Rect _windowRect = Rect.zero;
  bool _acceptsMouse = true;
  bool _applyingMouseMode = false;
  bool _isDraggingWindow = false;
  bool _isHovered = false;
  bool _chromeFocused = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    _channel.setMethodCallHandler(_handleMethodCall);
    _engine.onNeedsFrames = _requestFrames;
    _engine.start();
    _applyBehavior();
    _requestFrames();
    _viewportTimer = Timer.periodic(
      _viewportSyncInterval,
      (_) => _syncViewport(),
    );

    unawaited(_fetchInitialSettings());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        _channel.invokeMethod<void>('pipReady').catchError((Object _) {}),
      );

      _report('pipReady');
    });
  }

  @override
  void dispose() {
    SimplePrefs.instance.flush();
    WidgetsBinding.instance.removeObserver(this);
    _channel.setMethodCallHandler(null);
    _viewportTimer?.cancel();
    _restTimer?.cancel();
    _cancelHops();
    _cursorSub?.cancel();
    _wanderer.dispose();
    _ticker.dispose();
    _engine.onNeedsFrames = null;
    _engine.dispose();
    super.dispose();
  }

  @override
  void didChangeAccessibilityFeatures() {
    _applyBehavior();
  }

  /// Native-to-Dart commands from the main window (settings sync, theme/name updates, break events, visibility, wake/display changes).
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    final args = call.arguments;
    final map = args is Map ? stringKeyedMap(args) : null;

    switch (call.method) {
      case 'syncPiPSettings':
        if (map != null) _applySettings(OverlayConfig.fromJson(map));
        break;

      case 'updateCompanionTheme':
        final themeId = map?['themeId']?.toString();
        if (themeId != null) {
          setState(() {
            _themeId = themeId;
            _definition = _definitionFrom(map);
            _renderMode = map?['renderMode']?.toString() ?? _renderMode;
          });
          _warmArtwork();
        }
        break;

      case 'updateCompanionName':
      case 'updatePetName':
        final name = map?['petName']?.toString();
        if (name != null && name.trim().isNotEmpty) {
          setState(() => _petName = name.trim());
          _engine.nudge();
        }
        break;

      case 'triggerCompanionState':
        _handleCompanionEvent(map?['state']?.toString());
        break;

      case 'setWindowVisible':
        _setWindowVisible(map?['visible'] != false);
        break;

      case 'systemDidWake':
      case 'displaysChanged':
        unawaited(_reconcileAfterSuspend());
        break;
    }
    return null;
  }

  Future<void> _fetchInitialSettings() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getInitialSettings',
      );
      if (result != null) {
        _applySettings(OverlayConfig.fromJson(stringKeyedMap(result)));
      }
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }

    await _windowManager.initialize();
    await _syncViewport();

    if (mounted) _wanderer.start();
  }

  void _applySettings(OverlayConfig config) {
    if (!mounted) return;

    setState(() {
      _themeId = config.themeId ?? _themeId;
      _petName = config.petName ?? _petName;
      _renderMode = config.renderMode ?? _renderMode;
      _scale = (config.scale ?? _scale).clamp(2.0, 15.0).toDouble();
      _clickThrough = config.clickThrough ?? _clickThrough;
      _pipOpacity = config.pipOpacity ?? _pipOpacity;
      _keepOnScreen = config.keepOnScreen ?? _keepOnScreen;
      _backdrop = config.pipBackgroundStyle ?? _backdrop;
      _pipDraggableClickable =
          config.pipDraggableClickable ?? _pipDraggableClickable;
      _pettingEnabled = config.pettingEnabled ?? _pettingEnabled;
      _playEnabled = config.playEnabled ?? _playEnabled;
      _treatEnabled = config.treatEnabled ?? _treatEnabled;
      _gazeEnabled = config.gazeEnabled ?? _gazeEnabled;
      _gazeSensitivity = (config.gazeSensitivity ?? _gazeSensitivity)
          .clamp(0.0, 1.0)
          .toDouble();
      _idleAnimation = config.idleAnimation ?? _idleAnimation;
      _reactions = config.reactionsEnabled ?? _reactions;
      _reducedMotionSetting = config.reducedMotion ?? _reducedMotionSetting;
      _animationsEnabled = config.animationsEnabled ?? _animationsEnabled;

      final incoming = config.avatarDefinitionJson;
      if (incoming != null && incoming.isNotEmpty) {
        _definition = _tryParseDefinition(incoming) ?? _definition;
      }
    });

    _wanderingRequested = config.wanderingEnabled ?? _wanderingRequested;
    unawaited(_windowManager.setOpacity(_pipOpacity));
    final acceptsMouse = _pipDraggableClickable && !_clickThrough;
    _acceptsMouse = acceptsMouse;
    unawaited(_windowManager.setAcceptsMouse(acceptsMouse));
    _applyBehavior();
    _syncHitTestSubscription();
    _warmArtwork();
  }

  AvatarDefinition? _definitionFrom(Map<String, dynamic>? map) {
    final raw = map?['avatarDefinitionJson'];
    if (raw is String && raw.isNotEmpty) {
      return _tryParseDefinition(raw) ?? _definition;
    }
    return _definition;
  }

  AvatarDefinition? _tryParseDefinition(String encoded) {
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return null;
      return AvatarDefinition.fromJson(Map<String, dynamic>.from(decoded));
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
      return null;
    }
  }

  void _warmArtwork() {
    if (_isBlob) return;
    unawaited(
      AvatarArtworkLoader.precache(<AvatarArtworkRecipe>[
        avatarRecipeFor(_avatarDefinition),
      ]),
    );
  }

  bool get _isBlob {
    final mode = _renderMode;
    if (mode != null && mode.isNotEmpty) return mode == 'blob';
    if (_themeId == 'blobatar') return true;
    return PetTheme.getTheme(_themeId).isBlobatar;
  }

  AvatarDefinition get _avatarDefinition {
    final explicit = _definition;
    if (explicit != null) return explicit;

    final theme = PetTheme.getTheme(_themeId);
    if (theme.avatarDefinition != null) return theme.avatarDefinition!;

    final cleanId = _themeId.startsWith('avatar_')
        ? _themeId.substring('avatar_'.length)
        : _themeId;
    final species =
        AvatarSpecies.tryParse(cleanId) ??
        AvatarSpecies.tryParse(_themeId) ??
        AvatarSpecies.cat;
    return AvatarDefinition.fromSpecies(species);
  }

  void _applyBehavior() {
    final reduced = _reducedMotionSetting || prefersReducedMotion;
    _engine.configure(
      gaze: GazeSettings(enabled: _gazeEnabled, sensitivity: _gazeSensitivity),
      idleAnimation: _idleAnimation,
      reactions: _reactions,
      animations: _animationsEnabled,
      reducedMotion: reduced,
    );

    _wanderer.enabled = _wanderingRequested && _animationsEnabled && !reduced;
  }

  void _handleCompanionEvent(String? name) {
    switch (name) {
      case 'breakCompleted':
        _engine.onBreakCompleted();
      case 'breakReminder':
        _engine.onBreakReminder();
      default:
        _engine.nudge();
    }
  }

  /// Frame loop is on-demand: a ticker runs only while the engine is moving, otherwise a slow rest timer polls until it settles.
  void _requestFrames() {
    if (!mounted || !_windowVisible) return;
    _restTimer?.cancel();
    _restTimer = null;
    if (!_ticker.isActive) _ticker.start();
  }

  void _tickEngine(Duration _) {
    final now = _clock.elapsed;
    if (now - _lastFrameElapsed < _engine.frameInterval) return;
    _lastFrameElapsed = now;
    _engine.tick(now);

    if (_engine.isSettled) _enterRest();
  }

  void _enterRest() {
    if (_ticker.isActive) _ticker.stop();
    _restTimer ??= Timer.periodic(_restInterval, (_) {
      if (!mounted) return;
      _engine.tick(_clock.elapsed);
      if (!_engine.isSettled) _requestFrames();
    });
  }

  /// Hidden windows stop the ticker and cursor polling to save CPU.
  void _setWindowVisible(bool visible) {
    if (_windowVisible == visible) return;
    _windowVisible = visible;
    _engine.setSuspended(!visible);
    if (visible) {
      _requestFrames();
      unawaited(_syncViewport());
    } else {
      if (_ticker.isActive) _ticker.stop();
      _restTimer?.cancel();
      _restTimer = null;
    }
    _syncHitTestSubscription();
  }

  /// After sleep or a display change, drop cached display geometry and re-sync viewport and position.
  Future<void> _reconcileAfterSuspend() async {
    _windowManager.invalidateDisplayCache();
    _engine.reconcile();
    await _syncViewport();

    _windowManager.persistPosition();
    _requestFrames();
  }

  bool get _needsHitTesting => _windowVisible && _pipDraggableClickable;

  void _syncHitTestSubscription() {
    if (_needsHitTesting && _cursorSub == null) {
      _cursorSub = CursorFeed.instance.subscribe(_onCursorSample);
    } else if (!_needsHitTesting && _cursorSub != null) {
      _cursorSub!.cancel();
      _cursorSub = null;
    }
  }

  /// Toggles whether the window accepts mouse by cursor position (click-through elsewhere); _applyingMouseMode avoids overlapping native calls.
  void _onCursorSample(CursorSample sample) {
    if (!mounted || _isDraggingWindow) return;

    if (!_windowRect.isEmpty) {
      _setHovered(_windowRect.inflate(2).contains(sample.position));
    }

    final shouldAccept = shouldWindowAcceptMouse(
      draggableClickable: _pipDraggableClickable,
      clickThrough: _clickThrough,
      hasBackdrop: _hasBackdrop,
      hovered: _isHovered,
      cursor: sample.position,
      windowRect: _windowRect,
      stageRect: _stageGlobalRect,
    );

    if (shouldAccept == _acceptsMouse || _applyingMouseMode) return;
    _acceptsMouse = shouldAccept;
    _applyingMouseMode = true;
    _windowManager.setAcceptsMouse(shouldAccept).whenComplete(() {
      _applyingMouseMode = false;
    });
  }

  void _setHovered(bool hovered) {
    if (_isHovered == hovered || !mounted) return;
    setState(() => _isHovered = hovered);
    if (hovered) {
      _wanderer.suspend();
    } else {
      _wanderer.resume();
    }

    _engine.hover(hovered);
  }

  Rect get _stageGlobalRect {
    final local = _stageLocalRect;
    if (local == null || _windowRect.isEmpty) return Rect.zero;
    return local.shift(_windowRect.topLeft);
  }

  Rect? _stageLocalRect;

  Offset? get _eyeGlobal {
    final stage = _stageGlobalRect;
    if (stage.isEmpty) return null;
    return Offset(stage.center.dx, stage.top + stage.height * 0.38);
  }

  Future<void> _syncViewport() async {
    try {
      final position = await _windowManager.getPosition();
      final size = _windowManager.currentSize;
      _windowRect = Rect.fromLTWH(
        position.dx,
        position.dy,
        size.width,
        size.height,
      );
      _engine.setViewport(_windowRect, eye: _eyeGlobal);
    } catch (_) {}
  }

  void _handlePetTap() {
    _engine.pet();
    _wanderer.suspend();
  }

  Future<void> _startWindowDrag() async {
    if (!_pipDraggableClickable || _isDraggingWindow) return;
    _isDraggingWindow = true;
    _wanderer.suspend();
    _engine.grab();

    try {
      if (!_acceptsMouse) {
        _acceptsMouse = true;
        await _windowManager.setAcceptsMouse(true);
      }
      await _windowManager.startDrag();
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    } finally {
      _isDraggingWindow = false;
      _engine.release();
      await _syncViewport();
      _wanderer.resume();
    }
  }

  void _handleWish(PetWish wish) {
    switch (wish) {
      case PetWish.petting:
        _engine.pet();
        _playEffect(PetInteractionKind.pet);
      case PetWish.play:
        _engine.play();
        _playEffect(PetInteractionKind.play);
      case PetWish.treat:
        _engine.feed();
        _playEffect(PetInteractionKind.treat);
      case PetWish.rest:
        _engine.onBreakTaken();
        _engine.pet();
        _report('takeBreak');
      case PetWish.none:
        break;
    }

    _wanderer.suspend();
  }

  void _playEffect(PetInteractionKind kind) {
    _cancelHops();
    setState(() {
      _effectKind = kind;
      _effectSeq++;
    });
    for (final hop in kind.hops) {
      _hopTimers.add(
        Timer(kind.duration * hop.at, () => _engine.hop(hop.strength)),
      );
    }
  }

  void _cancelHops() {
    for (final timer in _hopTimers) {
      timer.cancel();
    }
    _hopTimers.clear();
  }

  void _report(String interactionType) {
    unawaited(
      IpcBridge.instance.dispatch(
        IpcEvent.companionInteraction(
          interactionType: interactionType,
          metadata: <String, dynamic>{'petName': _petName},
        ),
      ),
    );
  }

  void _handleRename() {
    unawaited(
      IpcBridge.instance.dispatch(
        IpcEvent.companionInteraction(
          interactionType: 'openBlobatarEditor',
          metadata: <String, dynamic>{'petName': _petName},
        ),
      ),
    );
    unawaited(NativeBridge.focusApp());
  }

  Future<void> _handleClose() async {
    SimplePrefs.instance.flush();
    try {
      await IpcBridge.instance.dispatch(
        IpcEvent.companionInteraction(
          interactionType: 'closeCompanion',
          metadata: <String, dynamic>{'petName': _petName},
        ),
      );
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }

    await NativeBridge.hidePipWindow();
  }

  void _toggleKeepOnScreen() {
    final next = !_keepOnScreen;
    setState(() => _keepOnScreen = next);
    SimplePrefs.instance.setBool('companion_keep_on_screen', next);
    unawaited(
      IpcBridge.instance.dispatch(
        IpcEvent.companionInteraction(
          interactionType: 'keepOnScreen',
          metadata: <String, dynamic>{'value': next},
        ),
      ),
    );
    _engine.nudge();
  }

  static final Color _chromeForeground = AppTheme.gray100;
  static final Color _chromeBackground = AppTheme.gray950.withValues(
    alpha: 0.68,
  );

  Color? get _backdropColor {
    switch (_backdrop) {
      case 'none':
      case 'transparent':
        return null;
      case 'scene':
        return kSceneAuthoredBackground;
      default:
        final hex = _backdrop.startsWith('#')
            ? _backdrop.substring(1)
            : _backdrop;
        final value = int.tryParse(hex, radix: 16);
        return value == null
            ? kSceneAuthoredBackground
            : Color(0xFF000000 | value);
    }
  }

  bool get _hasBackdrop => _backdrop != 'none' && _backdrop != 'transparent';

  double get _petSizeFactor {
    final normalized = ((_scale - 2.0) / 13.0).clamp(0.0, 1.0);
    return 0.88 + normalized * 0.12;
  }

  List<PetWish> get _availableActions => <PetWish>[
    if (_pettingEnabled) PetWish.petting,
    if (_playEnabled) PetWish.play,
    if (_treatEnabled) PetWish.treat,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Opacity(
        opacity: _pipOpacity.clamp(0.2, 1.0),
        child: MouseRegion(
          onEnter: (_) => _setHovered(true),
          onExit: (_) => _setHovered(false),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanStart: _pipDraggableClickable
                ? (_) => unawaited(_startWindowDrag())
                : null,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned.fill(child: _buildPet()),
                if (_effectKind != null && _stageLocalRect != null)
                  Positioned.fromRect(
                    rect: _stageLocalRect!,
                    child: PetInteractionEffect(
                      key: ValueKey<int>(_effectSeq),
                      kind: _effectKind!,
                      size: _stageLocalRect!.width,
                      onDone: () {
                        if (mounted) setState(() => _effectKind = null);
                      },
                    ),
                  ),
                Positioned.fill(child: _buildChrome()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPet() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const topHeadroom = 34.0;
        const bottomHeadroom = 52.0;
        const horizontalInset = 12.0;
        final safeWidth = math.max(
          48.0,
          constraints.maxWidth - horizontalInset * 2,
        );
        final safeHeight = math.max(
          48.0,
          constraints.maxHeight - topHeadroom - bottomHeadroom,
        );
        final safeExtent = math.min(safeWidth, safeHeight);
        final stageSize = math.max(48.0, safeExtent * _petSizeFactor);
        _stageLocalRect = Rect.fromLTWH(
          (constraints.maxWidth - stageSize) / 2,
          topHeadroom +
              (constraints.maxHeight -
                      topHeadroom -
                      bottomHeadroom -
                      stageSize) /
                  2,
          stageSize,
          stageSize,
        );

        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalInset,
            topHeadroom,
            horizontalInset,
            bottomHeadroom,
          ),
          child: Align(
            alignment: Alignment.center,
            child: AnimatedBuilder(
              animation: _engine,
              builder: (context, _) => Semantics(
                label: _semanticLabel(_engine.snapshot.mood),
                button: true,
                onTap: _handlePetTap,
                excludeSemantics: true,
                child: PetStage(
                  snapshot: _engine.snapshot,
                  size: stageSize,
                  definition: _isBlob ? null : _avatarDefinition,
                  blobName: _isBlob ? _petName : null,
                  background: _backdropColor,

                  showShadow: false,
                  showSceneShadow: _hasBackdrop,
                  onTap: _handlePetTap,
                  onDoubleTap: _isBlob ? _handleRename : null,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _semanticLabel(CompanionMood mood) {
    final name = _petName.trim().isEmpty ? 'Companion' : _petName.trim();
    final feeling = switch (mood) {
      CompanionMood.idle => 'relaxed',
      CompanionMood.sleepy => 'sleepy',
      CompanionMood.curious => 'curious',
      CompanionMood.attentive => 'paying attention',
      CompanionMood.happy => 'happy',
      CompanionMood.encouraging => 'encouraging you to take a break',
      CompanionMood.surprised => 'surprised',
      CompanionMood.resting => 'resting',
    };
    return '$name, $feeling. Activate to pet.';
  }

  Widget _buildChrome() {
    final showChrome = _isHovered || _chromeFocused;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,

      onFocusChange: (focused) {
        if (_chromeFocused != focused) setState(() => _chromeFocused = focused);
      },
      child: AnimatedOpacity(
        opacity: showChrome ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: IgnorePointer(
          ignoring: !showChrome,
          child: Stack(
            children: <Widget>[
              Positioned(
                top: 6,
                left: 0,
                right: 0,
                child: Center(
                  child: _DottedDragHandle(
                    foreground: _chromeForeground,
                    background: _chromeBackground,
                    onDragStart: () => unawaited(_startWindowDrag()),
                    onDragEnd: () {},
                  ),
                ),
              ),

              Positioned(
                top: 6,
                right: 6,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _ChromeButton(
                      icon: _keepOnScreen
                          ? Icons.push_pin_rounded
                          : Icons.push_pin_outlined,
                      background: _chromeBackground,
                      foreground: _chromeForeground,
                      isActive: _keepOnScreen,
                      tooltip: _keepOnScreen
                          ? 'Staying on screen — tap to only show during breaks'
                          : 'Only shows during breaks — tap to keep on screen',
                      onTap: _toggleKeepOnScreen,
                    ),
                    const SizedBox(width: 4),
                    _ChromeButton(
                      icon: Icons.close_rounded,
                      background: _chromeBackground,
                      foreground: _chromeForeground,
                      tooltip: 'Turn companion off',
                      onTap: _handleClose,
                    ),
                  ],
                ),
              ),

              Positioned(
                top: 6,
                left: 6,
                right: 60,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (_isBlob) ...<Widget>[
                      _ChromeButton(
                        icon: Icons.edit_rounded,
                        background: _chromeBackground,
                        foreground: _chromeForeground,
                        tooltip:
                            'Rename '
                            '${_petName.trim().isEmpty ? 'companion' : _petName}',
                        onTap: _handleRename,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: _NamePill(
                        name: _petName,
                        background: _chromeBackground,
                        foreground: _chromeForeground,
                      ),
                    ),
                  ],
                ),
              ),

              Positioned(
                left: 0,
                right: 0,
                bottom: 8,
                child: Center(
                  child: AnimatedBuilder(
                    animation: _engine,
                    builder: (context, _) => _ActionBar(
                      actions: _availableActions,
                      suggested: _engine.wish,
                      background: _chromeBackground,
                      foreground: _chromeForeground,
                      onSelected: _handleWish,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
