import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:breakmate/core/native/native_bridge.dart';
import 'package:breakmate/features/companion/domain/avatar_definition.dart';
import 'package:breakmate/features/companion/domain/avatar_species.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/presentation/widgets/avatar_view.dart';
import 'package:breakmate/features/companion/services/companion_window_manager.dart';
import 'package:breakmate/features/companion/services/display_manager.dart';
import 'package:breakmate/core/errors/error_handler.dart';
import 'package:breakmate/core/services/simple_prefs.dart';
import 'package:breakmate/core/ipc/overlay_config.dart';

class PiPOverlayWindow extends StatefulWidget {
  const PiPOverlayWindow({super.key});

  @override
  State<PiPOverlayWindow> createState() => _PiPOverlayWindowState();
}

class _PiPOverlayWindowState extends State<PiPOverlayWindow> {
  static const MethodChannel _channel = MethodChannel(
    'com.breakmate.desktop/pip_data',
  );

  late String _themeId = SimplePrefs.instance.getString(
    'companion_pet_theme',
    defaultValue: 'avatar_cat',
  );
  String _petName = 'Lily';
  late double _scale = SimplePrefs.instance.getDouble(
    'companion_scale',
    defaultValue: 3.2,
  );

  late final CompanionWindowManager _windowManager = CompanionWindowManager(
    displayManager: NativeDisplayManager(),
  );

  bool _clickThrough = false;
  bool _acceptsMouse = true;
  Timer? _clickThroughTimer;

  late String _pipBackgroundStyle = SimplePrefs.instance.getString(
    'pip_background_style',
    defaultValue: 'transparent',
  );
  late double _pipOpacity = SimplePrefs.instance.getDouble(
    'pip_opacity',
    defaultValue: 1.0,
  );
  late bool _pipDraggableClickable = SimplePrefs.instance.getBool(
    'pip_draggable_clickable',
    defaultValue: true,
  );

  Offset _screenLookAt = Offset.zero;
  bool _isHovered = false;
  DateTime? _lastHoverTime;
  bool _isCheckingClickThrough = false;
  String? _feedbackText;
  Timer? _feedbackTimer;

  // Dedicated 3D gaze tracking — always fires, independent of click-through
  Timer? _gazeTrackingTimer;
  bool _isTrackingGaze = false;
  // Smoothed gaze — lerped toward the raw cursor position each frame
  Offset _smoothedLookAt = Offset.zero;

  @override
  void initState() {
    super.initState();

    _channel.setMethodCallHandler(_handleMethodCall);
    _fetchInitialSettings();

    // Click-through check: 33 ms cadence
    _clickThroughTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      _checkClickThrough();
    });

    // 3D gaze tracking: 16 ms (~60 fps) cadence — always active
    _gazeTrackingTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      _updateGaze();
    });
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    _feedbackTimer?.cancel();
    _clickThroughTimer?.cancel();
    _gazeTrackingTimer?.cancel();
    super.dispose();
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'syncPiPSettings':
        final args = call.arguments as Map<dynamic, dynamic>?;
        if (args != null) {
          _applySettings(OverlayConfig.fromJson(Map<String, dynamic>.from(args)));
        }
        break;
      case 'updateCompanionTheme':
        final args = call.arguments as Map<dynamic, dynamic>?;
        if (args != null && args['themeId'] != null) {
          setState(() {
            _themeId = args['themeId'].toString();
          });
        }
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
    await _windowManager.initialize();
  }

  void _applySettings(OverlayConfig config) {
    if (!mounted) return;

    final newThemeId = config.themeId ?? _themeId;
    final newScale = config.scale ?? _scale;
    final newPetName = config.petName ?? _petName;
    final newClickThrough = config.clickThrough ?? _clickThrough;
    final newPipBackgroundStyle =
        config.pipBackgroundStyle ?? _pipBackgroundStyle;
    final newPipOpacity = config.pipOpacity ?? _pipOpacity;
    final newPipDraggableClickable =
        config.pipDraggableClickable ?? _pipDraggableClickable;

    setState(() {
      _themeId = newThemeId;
      _scale = newScale > 0 ? newScale : 3.2;
      _petName = newPetName;
      _clickThrough = newClickThrough;
      _pipBackgroundStyle = newPipBackgroundStyle;
      _pipOpacity = newPipOpacity;
      _pipDraggableClickable = newPipDraggableClickable;
    });

    _windowManager.setOpacity(_pipOpacity);
    _checkClickThrough();
  }

  /// Runs at ~60 fps. Gets the native cursor position, computes a normalised
  /// [-1, 1] look-at offset relative to the PiP window center, and lerps
  /// _smoothedLookAt toward it so the avatar head movement is silky smooth.
  Future<void> _updateGaze() async {
    if (_isTrackingGaze || !mounted) return;
    _isTrackingGaze = true;
    try {
      final pos = await _windowManager.getPosition();
      final size = _windowManager.currentSize;
      final cursorPos = await NativeBridge.getCursorPosition();

      final windowCenter =
          Offset(pos.dx + size.width / 2.0, pos.dy + size.height / 2.0);
      final dx = cursorPos.dx - windowCenter.dx;
      final dy = cursorPos.dy - windowCenter.dy;

      // Sensitivity: divide by a fraction of screen width so nearby motion
      // gives strong reaction, far-away gives subtle look.
      final range = math.max(size.width, size.height) * 1.4;
      final rawX = (dx / range).clamp(-1.0, 1.0);
      final rawY = (dy / range).clamp(-1.0, 1.0);
      final rawLook = Offset(rawX, rawY);

      // Lerp at ~0.12 per frame → smooth ~8-frame settling time at 60fps
      const lerpT = 0.12;
      final smoothed = Offset(
        _smoothedLookAt.dx + (rawLook.dx - _smoothedLookAt.dx) * lerpT,
        _smoothedLookAt.dy + (rawLook.dy - _smoothedLookAt.dy) * lerpT,
      );

      if (!mounted) return;
      if ((_smoothedLookAt - smoothed).distance > 0.003) {
        setState(() {
          _smoothedLookAt = smoothed;
          _screenLookAt = smoothed;
        });
      }
    } catch (_) {
    } finally {
      _isTrackingGaze = false;
    }
  }

  Future<void> _checkClickThrough() async {
    if (_isCheckingClickThrough) return;
    _isCheckingClickThrough = true;

    try {
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

      final pos = await _windowManager.getPosition();
      final size = _windowManager.currentSize;
      final cursorPos = await NativeBridge.getCursorPosition();

      final windowRect = Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height);

      bool accepts = true;
      if (windowRect.contains(cursorPos)) {
        final localX = cursorPos.dx - windowRect.left;
        final localY = cursorPos.dy - windowRect.top;

        final inCard =
            localX >= 4.0 &&
            localX <= (size.width - 4.0) &&
            localY >= 4.0 &&
            localY <= (size.height - 4.0);

        accepts = inCard;
      } else {
        accepts = false;
      }

      if (accepts != _acceptsMouse) {
        _acceptsMouse = accepts;
        await _windowManager.setAcceptsMouse(accepts);
      }
    } catch (_) {
    } finally {
      _isCheckingClickThrough = false;
    }
  }

  void _closeWindow() {
    NativeBridge.hidePipWindow();
  }

  void _onHover(PointerHoverEvent event) {
    final now = DateTime.now();
    if (_lastHoverTime != null &&
        now.difference(_lastHoverTime!) < const Duration(milliseconds: 800)) {
      return;
    }
    _lastHoverTime = now;
  }

  bool get _isLightBackground => _pipBackgroundStyle == 'light';

  Decoration _buildContainerDecoration() {
    if (_pipBackgroundStyle == 'transparent') {
      return const BoxDecoration(color: Colors.transparent);
    }

    if (_pipBackgroundStyle == 'light') {
      return BoxDecoration(
        color: const Color(0xFFF5F5FA),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF161622).withValues(alpha: 0.12),
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

    if (_pipBackgroundStyle == 'midnight') {
      return BoxDecoration(
        color: const Color(0xFF0F111D),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      );
    }

    return BoxDecoration(
      color: const Color(0xFF181924),
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

  AvatarDefinition get _avatarDefinition {
    final theme = PetTheme.getTheme(_themeId);
    if (theme.avatarDefinition != null) {
      return theme.avatarDefinition!;
    }
    final cleanId = _themeId.startsWith('avatar_')
        ? _themeId.substring('avatar_'.length)
        : _themeId;
    final species = AvatarSpecies.tryParse(cleanId) ??
        AvatarSpecies.tryParse(_themeId) ??
        AvatarSpecies.cat;
    return AvatarDefinition.fromSpecies(species);
  }

  @override
  Widget build(BuildContext context) {
    final isLight = _isLightBackground;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Opacity(
        opacity: _pipOpacity,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: Container(
            margin: EdgeInsets.zero,
            decoration: _buildContainerDecoration(),
            clipBehavior: Clip.none,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. Centered Authentic Animated SVG Vector Companion filling viewport
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final petSize = math.min(constraints.maxWidth, constraints.maxHeight);
                      return Center(
                        child: AvatarView(
                          definition: _avatarDefinition,
                          width: petSize,
                          height: petSize,
                          externalLookAt: _screenLookAt,
                          autoTrackCursor: true,
                          isInteractive: true,
                        ),
                      );
                    },
                  ),
                ),

                // 2. Drag Handle Bar across top (appears smoothly on hover)
                Positioned(
                  top: 6,
                  left: 0,
                  right: 0,
                  height: 24,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (_) => _windowManager.startDrag(),
                    child: AnimatedOpacity(
                      opacity: _isHovered ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Center(
                        child: Container(
                          width: 38,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isLight
                                ? const Color(0xFF161622).withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. Cute Pet Name Badge (fades in on hover)
                Positioned(
                  top: 14,
                  left: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    opacity: _isHovered ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Center(
                      child: _PetNameBadge(
                        name: _petName,
                        isLightBackground: isLight,
                      ),
                    ),
                  ),
                ),

                // 4. Hover Listener for Interaction
                Positioned.fill(
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerHover: _onHover,
                  ),
                ),

                // 5. Feedback Reaction Toast
                if (_feedbackText != null)
                  Positioned(
                    top: 24,
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

                // 6. Close Button (fades in on hover)
                Positioned(
                  top: 8,
                  right: 8,
                  child: AnimatedOpacity(
                    opacity: _isHovered ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: _CloseButton(
                      onTap: _closeWindow,
                      isLightBackground: isLight,
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

class _PetNameBadge extends StatelessWidget {
  const _PetNameBadge({required this.name, required this.isLightBackground});
  final String name;
  final bool isLightBackground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: isLightBackground
            ? const Color(0xFFE6E6F0).withValues(alpha: 0.9)
            : const Color(0xFF2D2D3E).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        name,
        style: TextStyle(
          color: isLightBackground
              ? const Color(0xFF161622)
              : const Color(0xFFEAEAFF),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter',
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap, required this.isLightBackground});
  final VoidCallback onTap;
  final bool isLightBackground;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: isLightBackground
              ? const Color(0xFFE2E2EC)
              : const Color(0xFF2C2C3E),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            Icons.close_rounded,
            size: 13,
            color: isLightBackground
                ? const Color(0xFF6E6E82)
                : const Color(0xFFA0A0BA),
          ),
        ),
      ),
    );
  }
}
