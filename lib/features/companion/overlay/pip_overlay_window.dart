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
import 'package:breakmate/features/companion/behavior/pet_emotion.dart';
import 'package:breakmate/features/companion/behavior/pet_wanderer.dart';
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

  late final PetWanderer _wanderer = PetWanderer.forWindow(
    windowManager: _windowManager,
    engine: _engine,
    // Wherever it walks to is where it now lives, so whatever the pet knows
    // about its own position has to be brought back into line.
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

  /// Which interactions the user has left switched on. Everything is on until
  /// the host says otherwise, so the affordances appear on the first frame
  /// rather than popping in once settings arrive.
  bool _pettingEnabled = true;
  bool _playEnabled = true;
  bool _treatEnabled = true;

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
    _wanderer.dispose();
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

    // Started only once the window manager knows where the window actually
    // is; before that the wanderer would be walking from a guess.
    if (mounted) _wanderer.start();
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
      _pettingEnabled = config.pettingEnabled ?? _pettingEnabled;
      _playEnabled = config.playEnabled ?? _playEnabled;
      _treatEnabled = config.treatEnabled ?? _treatEnabled;

      final incoming = config.avatarDefinitionJson;
      if (incoming != null && incoming.isNotEmpty) {
        _definition = _tryParseDefinition(incoming) ?? _definition;
      }
    });

    _wanderer.enabled = config.wanderingEnabled ?? _wanderer.enabled;
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
    _report('pet');
  }

  /// Carries out one of the offered interactions.
  ///
  /// Each one is two things at once: something that happens to the pet now,
  /// and a note to the host, which is the only side that can write settings or
  /// touch the break timer.
  void _handleWish(PetWish wish) {
    switch (wish) {
      case PetWish.petting:
        _engine.pet();
        _report('pet');
      case PetWish.play:
        _engine.play();
        _report('play');
      case PetWish.treat:
        _engine.feed();
        _report('treat');
      case PetWish.rest:
        _engine.onBreakTaken();
        _engine.pet();
        _report('takeBreak');
      case PetWish.none:
        break;
    }
    // Whatever just happened, the pet is now busy with the user.
    _wanderer.suspend();
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

  /// The interactions this window is allowed to offer, in the order they are
  /// shown. Resting is not in the list: it only appears when the companion
  /// actually asks for it.
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
          onEnter: (_) {
            setState(() => _isHovered = true);
            // Nothing walks off while it is being looked at.
            _wanderer.suspend();
          },
          onExit: (_) {
            setState(() => _isHovered = false);
            _wanderer.resume();
          },
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
            // Dotted grid drag handle along the top edge.
            Positioned(
              top: 6,
              left: 0,
              right: 0,
              child: Center(
                child: _DottedDragHandle(
                  foreground: _chromeForeground,
                  background: _chromeBackground,
                  onDragStart: () {
                    _wanderer.suspend();
                    _windowManager.startDrag();
                  },
                  onDragEnd: () {
                    _syncViewport();
                    _wanderer.resume();
                  },
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

            // Name and edit sit top-left so the bottom of the window is free
            // for the interactions, which are the part a new user needs.
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
                      tooltip: 'Rename '
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
    );
  }
}

/// How one interaction is presented.
class _WishStyle {
  const _WishStyle(this.icon, this.label, this.hint);

  final IconData icon;

  /// One word, shown under the row for whichever button is in play.
  final String label;

  /// The longer form, for the tooltip.
  final String hint;
}

const Map<PetWish, _WishStyle> _wishStyles = <PetWish, _WishStyle>{
  PetWish.petting: _WishStyle(
    Icons.back_hand_rounded,
    'Pet',
    'Give it a scratch',
  ),
  PetWish.play: _WishStyle(
    Icons.sports_baseball_rounded,
    'Play',
    'Throw something for it',
  ),
  PetWish.treat: _WishStyle(
    Icons.cookie_rounded,
    'Treat',
    'Offer a treat',
  ),
  PetWish.rest: _WishStyle(
    Icons.self_improvement_rounded,
    'Rest',
    'Start a break now',
  ),
};

/// The things a user can actually do to the companion, shown on hover.
///
/// The face says what the pet feels, and that was the whole of it before —
/// which left anyone seeing it for the first time with a wistful animal and no
/// idea that the answer was to click it. So the options appear under the pet
/// the moment the pointer arrives, with the one it would most appreciate right
/// now picked out in the accent colour, and a single word naming whichever
/// button is in play.
class _ActionBar extends StatefulWidget {
  const _ActionBar({
    required this.actions,
    required this.suggested,
    required this.background,
    required this.foreground,
    required this.onSelected,
  });

  /// The interactions the user has left switched on.
  final List<PetWish> actions;

  /// What the pet would most like. Highlighted, and prepended to the row when
  /// it is something the list does not already offer.
  final PetWish suggested;

  final Color background;
  final Color foreground;
  final ValueChanged<PetWish> onSelected;

  @override
  State<_ActionBar> createState() => _ActionBarState();
}

class _ActionBarState extends State<_ActionBar> {
  PetWish? _hovered;

  @override
  Widget build(BuildContext context) {
    final suggested = widget.suggested;
    final actions = <PetWish>[
      // Resting is the companion's own suggestion rather than a standing
      // option, so it is only ever here when it is being asked for.
      if (suggested == PetWish.rest) PetWish.rest,
      ...widget.actions,
    ];
    if (actions.isEmpty) return const SizedBox.shrink();

    // The hovered button wins the caption, because that is the one the user is
    // asking about. Otherwise it names what the pet wants.
    final labelled = _hovered ?? (actions.contains(suggested) ? suggested : null);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final action in actions) ...<Widget>[
              _ActionButton(
                style: _wishStyles[action]!,
                background: widget.background,
                foreground: widget.foreground,
                isSuggested: action == suggested,
                onEnter: () => setState(() => _hovered = action),
                onExit: () {
                  if (_hovered == action) setState(() => _hovered = null);
                },
                onTap: () => widget.onSelected(action),
              ),
              const SizedBox(width: 6),
            ],
          ]..removeLast(),
        ),
        SizedBox(
          height: 16,
          child: labelled == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _wishStyles[labelled]!.label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                      color: labelled == suggested
                          ? AppTheme.accent
                          : widget.foreground.withValues(alpha: 0.75),
                      shadows: const <Shadow>[
                        // The caption can land on anything from a dark card to
                        // a white desktop, so it carries its own contrast.
                        Shadow(blurRadius: 4, color: Color(0xCC000000)),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.style,
    required this.background,
    required this.foreground,
    required this.isSuggested,
    required this.onEnter,
    required this.onExit,
    required this.onTap,
  });

  final _WishStyle style;
  final Color background;
  final Color foreground;
  final bool isSuggested;
  final VoidCallback onEnter;
  final VoidCallback onExit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: style.hint,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => onEnter(),
        onExit: (_) => onExit(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: isSuggested
                  ? AppTheme.accent.withValues(alpha: 0.22)
                  : background,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSuggested
                    ? AppTheme.accent.withValues(alpha: 0.85)
                    : foreground.withValues(alpha: 0.14),
                width: isSuggested ? 1.4 : 1.0,
              ),
            ),
            child: Icon(
              style.icon,
              size: 15,
              color: isSuggested
                  ? AppTheme.accent
                  : foreground.withValues(alpha: 0.85),
            ),
          ),
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

/// The companion's name, and nothing else.
///
/// What it is feeling is on its face. Narrating that in a caption would say
/// the same thing twice and worse — a pet that has to tell you it is happy
/// is not a pet, it is a status bar.
class _NamePill extends StatelessWidget {
  const _NamePill({
    required this.name,
    required this.background,
    required this.foreground,
  });

  final String name;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final label = name.trim();
    if (label.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: foreground.withValues(alpha: 0.1)),
      ),
      child: Text(
        label,
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

/// A top drag grip displaying a 2x4 dotted grid with grab mouse cursors.
class _DottedDragHandle extends StatefulWidget {
  const _DottedDragHandle({
    required this.foreground,
    required this.background,
    required this.onDragStart,
    required this.onDragEnd,
  });

  final Color foreground;
  final Color background;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  @override
  State<_DottedDragHandle> createState() => _DottedDragHandleState();
}

class _DottedDragHandleState extends State<_DottedDragHandle> {
  bool _isHandleHovered = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final dotColor = widget.foreground.withValues(
      alpha: _isDragging ? 0.95 : (_isHandleHovered ? 0.8 : 0.45),
    );

    return Tooltip(
      message: 'Drag to move companion',
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: _isDragging
            ? SystemMouseCursors.grabbing
            : SystemMouseCursors.grab,
        onEnter: (_) => setState(() => _isHandleHovered = true),
        onExit: (_) => setState(() => _isHandleHovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) {
            setState(() => _isDragging = true);
            widget.onDragStart();
          },
          onPanEnd: (_) {
            setState(() => _isDragging = false);
            widget.onDragEnd();
          },
          onPanCancel: () {
            setState(() => _isDragging = false);
            widget.onDragEnd();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _isHandleHovered || _isDragging
                  ? widget.background.withValues(alpha: 0.85)
                  : widget.background.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.foreground.withValues(
                  alpha: _isDragging ? 0.3 : (_isHandleHovered ? 0.2 : 0.1),
                ),
                width: 1.0,
              ),
            ),
            child: SizedBox(
              width: 22,
              height: 8,
              child: CustomPaint(
                painter: _DottedGridPainter(color: dotColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for a clean 2x4 dotted grid.
class _DottedGridPainter extends CustomPainter {
  const _DottedGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const int cols = 4;
    const int rows = 2;
    const double radius = 1.25;

    final double stepX = cols > 1 ? (size.width - 2 * radius) / (cols - 1) : 0;
    final double stepY = rows > 1 ? (size.height - 2 * radius) / (rows - 1) : 0;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final cx = radius + c * stepX;
        final cy = radius + r * stepY;
        canvas.drawCircle(Offset(cx, cy), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DottedGridPainter oldDelegate) =>
      oldDelegate.color != color;
}

