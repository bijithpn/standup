import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'package:breakmate/core/errors/error_handler.dart';
import 'package:breakmate/core/ipc/ipc_bridge.dart';
import 'package:breakmate/core/ipc/ipc_events.dart';
import 'package:breakmate/core/ipc/overlay_config.dart';
import 'package:breakmate/core/native/native_bridge.dart';
import 'package:breakmate/core/services/simple_prefs.dart';
import 'package:breakmate/features/companion/behavior/cursor_feed.dart';
import 'package:breakmate/features/companion/behavior/pet_behavior_engine.dart';
import 'package:breakmate/features/companion/behavior/pet_behavior_snapshot.dart';
import 'package:breakmate/features/companion/domain/avatar_definition.dart';
import 'package:breakmate/features/companion/domain/avatar_species.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_3d_view.dart';
import 'package:breakmate/features/companion/presentation/widgets/pet_stage.dart';
import 'package:breakmate/features/companion/render/avatar_artwork.dart';
import 'package:breakmate/features/companion/render/avatar_artwork_loader.dart';
import 'package:breakmate/features/companion/render/avatar_artwork_recipe.dart';
import 'package:breakmate/features/companion/services/companion_window_manager.dart';
import 'package:breakmate/features/companion/services/display_manager.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// The floating companion window.
///
/// It runs in its own Flutter engine, so everything it needs about the pet
/// arrives over the `pip_data` channel. Motion comes from a single
/// [PetBehaviorEngine] on one ticker, reading one shared [CursorFeed] — the
/// previous version ran three independent polling timers that each made their
/// own native cursor call every frame.
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

  /// How often the window's own position is re-read. The pet only needs this
  /// to know where it is relative to the cursor, which tolerates being a frame
  /// or two stale — and the window rarely moves.
  static const Duration _viewportSyncInterval = Duration(milliseconds: 400);

  late final PetBehaviorEngine _engine = PetBehaviorEngine();
  late final Ticker _ticker = createTicker(_engine.tick);
  StreamSubscription<CursorSample>? _cursorSub;
  Timer? _viewportTimer;

  late final CompanionWindowManager _windowManager = CompanionWindowManager(
    displayManager: NativeDisplayManager(),
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
  late bool _pipDraggableClickable = SimplePrefs.instance.getBool(
    'pip_draggable_clickable',
    defaultValue: true,
  );
  late bool _keepOnScreen = SimplePrefs.instance.getBool(
    'companion_keep_on_screen',
    defaultValue: true,
  );

  /// How the card behind the companion is drawn: `scene` for the colour the
  /// avatar was authored with, `none` for nothing, or a `#RRGGBB` of your own.
  late String _backdrop = SimplePrefs.instance.getString(
    'pip_background_style',
    defaultValue: 'scene',
  );
  bool _clickThrough = false;

  Rect _windowRect = Rect.zero;
  bool _acceptsMouse = true;
  bool _applyingMouseMode = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();

    _channel.setMethodCallHandler(_handleMethodCall);
    _engine.start();
    _ticker.start();
    _cursorSub = CursorFeed.instance.subscribe(_onCursorSample);
    _viewportTimer = Timer.periodic(_viewportSyncInterval, (_) => _syncViewport());

    unawaited(_fetchInitialSettings());
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    _viewportTimer?.cancel();
    _cursorSub?.cancel();
    _ticker.dispose();
    _engine.dispose();
    super.dispose();
  }

  // ── Settings plumbing ─────────────────────────────────────────────────────

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    final args = call.arguments;
    final map = args is Map ? Map<String, dynamic>.from(args) : null;

    switch (call.method) {
      case 'syncPiPSettings':
        if (map != null) _applySettings(OverlayConfig.fromJson(map));
        break;

      // The host sends these as individual updates as well as inside a full
      // sync. Handling both is what keeps a rename or a re-style from being
      // silently dropped.
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
        _engine.nudge();
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
        _applySettings(
          OverlayConfig.fromJson(Map<String, dynamic>.from(result)),
        );
      }
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }

    await _windowManager.initialize();
    await _syncViewport();
  }

  void _applySettings(OverlayConfig config) {
    if (!mounted) return;

    setState(() {
      _themeId = config.themeId ?? _themeId;
      _petName = config.petName ?? _petName;
      _renderMode = config.renderMode ?? _renderMode;
      _clickThrough = config.clickThrough ?? _clickThrough;
      _pipOpacity = config.pipOpacity ?? _pipOpacity;
      _keepOnScreen = config.keepOnScreen ?? _keepOnScreen;
      _backdrop = config.pipBackgroundStyle ?? _backdrop;
      _pipDraggableClickable =
          config.pipDraggableClickable ?? _pipDraggableClickable;

      final incoming = config.avatarDefinitionJson;
      if (incoming != null && incoming.isNotEmpty) {
        _definition = _tryParseDefinition(incoming) ?? _definition;
      }
    });

    unawaited(_windowManager.setOpacity(_pipOpacity));
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

  /// Compiles the pet's artwork before the first frame that needs it, so it
  /// never appears as an empty box while the window fades in.
  void _warmArtwork() {
    if (_isBlob) return;
    unawaited(
      AvatarArtworkLoader.precache(<AvatarArtworkRecipe>[
        avatarRecipeFor(_avatarDefinition),
      ]),
    );
  }

  // ── Pet identity ──────────────────────────────────────────────────────────

  /// Whether the companion is the generative blob rather than illustrated
  /// artwork.
  ///
  /// The host says so explicitly through [OverlayConfig.renderMode]; the theme
  /// id is only a fallback. Deciding from the id alone is unreliable in both
  /// directions, because `PetTheme.getTheme` answers with the blob theme for
  /// anything it does not recognise.
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
    final species = AvatarSpecies.tryParse(cleanId) ??
        AvatarSpecies.tryParse(_themeId) ??
        AvatarSpecies.cat;
    return AvatarDefinition.fromSpecies(species);
  }

  // ── Cursor, viewport, click-through ───────────────────────────────────────

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
      _engine.setViewport(_windowRect);
    } catch (_) {
      // The window may be mid-move or already gone.
    }
  }

  /// Decides whether the window should swallow clicks.
  ///
  /// This reuses the shared cursor sample rather than asking the platform
  /// again, so click-through costs nothing beyond the poll the pet already
  /// needed to know where to look.
  void _onCursorSample(CursorSample sample) {
    if (!mounted) return;

    final bool shouldAccept;
    if (!_pipDraggableClickable) {
      shouldAccept = false;
    } else if (!_clickThrough) {
      shouldAccept = true;
    } else {
      shouldAccept =
          !_windowRect.isEmpty && _windowRect.deflate(4).contains(sample.position);
    }

    if (shouldAccept == _acceptsMouse || _applyingMouseMode) return;
    _acceptsMouse = shouldAccept;
    _applyingMouseMode = true;
    _windowManager.setAcceptsMouse(shouldAccept).whenComplete(() {
      _applyingMouseMode = false;
    });
  }

  // ── Interaction ───────────────────────────────────────────────────────────

  void _handlePetTap() {
    _engine.pet();
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
    await NativeBridge.hidePipWindow();
  }

  /// Toggles whether the companion stays out all the time or only shows up
  /// while a break is running.
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

  // ── Appearance ────────────────────────────────────────────────────────────

  // The chrome has to stay readable whether the pet sits on its own card or
  // straight on the desktop, so it carries its own scrim either way.
  static final Color _chromeForeground = AppTheme.gray100;
  static final Color _chromeBackground =
      AppTheme.gray950.withValues(alpha: 0.68);

  /// The card colour to draw behind the companion, or null for none.
  Color? get _backdropColor {
    switch (_backdrop) {
      case 'none':
      case 'transparent':
        return null;
      case 'scene':
        return kSceneAuthoredBackground;
      default:
        final hex = _backdrop.startsWith('#') ? _backdrop.substring(1) : _backdrop;
        final value = int.tryParse(hex, radix: 16);
        return value == null ? kSceneAuthoredBackground : Color(0xFF000000 | value);
    }
  }

  bool get _hasBackdrop => _backdrop != 'none' && _backdrop != 'transparent';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Opacity(
        opacity: _pipOpacity.clamp(0.2, 1.0),
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(child: _buildPet()),
              Positioned.fill(child: _buildChrome()),
            ],
          ),
        ),
      ),
    );
  }

  /// The pet itself. Rebuilt every frame, and nothing else is.
  Widget _buildPet() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final extent = math.min(constraints.maxWidth, constraints.maxHeight);
        final stageSize = math.max(48.0, extent - petStageInset(extent) * 2);

        return Center(
          child: AnimatedBuilder(
            animation: _engine,
            builder: (context, _) => PetStage(
              snapshot: _engine.snapshot,
              size: stageSize,
              definition: _isBlob ? null : _avatarDefinition,
              blobName: _isBlob ? _petName : null,
              background: _backdropColor,
              // The contact shadow needs a surface to fall on.
              showShadow: false,
              showSceneShadow: _hasBackdrop,
              onTap: _handlePetTap,
              onDoubleTap: _isBlob ? _handleRename : null,
            ),
          ),
        );
      },
    );
  }

  /// Everything that is not the pet: drag grip, name, close, status. All of it
  /// fades away when the pointer leaves, so the resting state is just an animal
  /// on the desktop.
  Widget _buildChrome() {
    return AnimatedOpacity(
      opacity: _isHovered ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: IgnorePointer(
        ignoring: !_isHovered,
        child: Stack(
          children: <Widget>[
            // Drag anywhere along the top edge.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 34,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => _windowManager.startDrag(),
                onPanEnd: (_) => _syncViewport(),
                child: Center(
                  child: Container(
                    width: 34,
                    height: 4,
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: _chromeForeground.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
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
                    tooltip: 'Hide companion',
                    onTap: _handleClose,
                  ),
                ],
              ),
            ),

            if (_isBlob)
              Positioned(
                top: 6,
                left: 6,
                child: _ChromeButton(
                  icon: Icons.edit_rounded,
                  background: _chromeBackground,
                  foreground: _chromeForeground,
                  tooltip: 'Rename ${_petName.trim().isEmpty ? 'companion' : _petName}',
                  onTap: _handleRename,
                ),
              ),

            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: Center(
                child: AnimatedBuilder(
                  animation: _engine,
                  builder: (context, _) => _StatusPill(
                    name: _petName,
                    activity: _engine.snapshot.activity,
                    background: _chromeBackground,
                    foreground: _chromeForeground,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small round control in the window chrome.
class _ChromeButton extends StatelessWidget {
  const _ChromeButton({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.tooltip,
    required this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final String tooltip;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive
                    ? AppTheme.accent.withValues(alpha: 0.6)
                    : foreground.withValues(alpha: 0.12),
              ),
            ),
            child: Icon(
              icon,
              size: 13,
              color: isActive
                  ? AppTheme.accent
                  : foreground.withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
    );
  }
}

/// The pet's name and what it is currently up to.
class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.name,
    required this.activity,
    required this.background,
    required this.foreground,
  });

  final String name;
  final PetActivity activity;
  final Color background;
  final Color foreground;

  String get _label {
    final petName = name.trim().isEmpty ? 'Your companion' : name.trim();
    switch (activity) {
      case PetActivity.sleeping:
        return '$petName is asleep';
      case PetActivity.drowsy:
        return '$petName is dozing off';
      case PetActivity.idle:
        return petName;
      case PetActivity.curious:
        return '$petName noticed you';
      case PetActivity.watching:
        return '$petName is watching you';
      case PetActivity.playful:
        return '$petName wants to play';
      case PetActivity.startled:
        return 'You startled $petName';
      case PetActivity.delighted:
        return '$petName loves that';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: foreground.withValues(alpha: 0.1)),
      ),
      child: Text(
        _label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
          color: foreground.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}
