import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:flutter/services.dart';
import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:tray_manager/tray_manager.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:breakmate/features/companion/assets/pet_asset_loader.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/domain/pet_animation_state.dart';
import 'package:breakmate/features/companion/domain/animation_row_config.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/features/companion/domain/avatar_definition.dart';
import 'controllers/menu_bar_controller.dart';
import 'tray_avatar_renderer.dart';
import 'package:breakmate/core/errors/error_handler.dart';

enum TrayIconMode { defaultIcon, companion, minimal, countdownOnly }

class TrayManagerService with TrayListener, WidgetsBindingObserver {
  final AppLogger _logger = AppLogger();
  bool _isMeetingActive = false;
  TrayIconMode _iconMode = TrayIconMode.companion;

  Timer? _animTimer;
  bool _isActionActive = false;
  Timer? _actionAnimTimer;
  int _currentFrameIndex = 0;

  TimerEngine? _timerEngine;
  BreakController? _breakController;
  MenuBarController? _menuBarController;
  final SettingsRepository? _settingsRepository;

  SettingsRepository? get _settingsRepo =>
      _settingsRepository ??
      (sl.isRegistered<SettingsRepository>() ? sl<SettingsRepository>() : null);

  TrayManagerService({
    TimerEngine? timerEngine,
    BreakController? breakController,
    MenuBarController? menuBarController,
    SettingsRepository? settingsRepository,
  }) : _settingsRepository = settingsRepository {
    _menuBarController = menuBarController;
    if (timerEngine != null && breakController != null) {
      setDependencies(timerEngine, breakController);
    }
  }

  // Menu bar style ('countdown', 'progress', 'icon', 'focusdot') and the
  // animated, drawn icon used by 'progress' / 'focusdot'.
  String _menuStyle = 'countdown';
  double _progress = 0;
  double _shownProgress = 0;
  double _pulse = 0;
  Timer? _progressAnimTimer;
  Timer? _pulseTimer;
  bool _onBreak = false;
  String? _lastDrawnKey;
  final Map<String, Uint8List> _drawnCache = {};

  bool get _usesDrawnIcon =>
      !Platform.isWindows &&
      (_menuStyle == 'progress' ||
          _menuStyle == 'focusdot' ||
          (_menuStyle == 'icon' && _iconMode != TrayIconMode.companion));

  final Map<PetAnimationState, List<String>> _stateFramePaths = {};
  Map<PetAnimationState, List<Uint8List>>? _avatarFrames;
  String? _lastAvatarKey;
  String? _defaultIconPath;
  String? _lastAppliedIconPath;
  String _currentTitle = '';

  Future<void> init() async {
    trayManager.addListener(this);
    WidgetsBinding.instance.addObserver(this);

    final settingsRepo = _settingsRepo;
    if (settingsRepo != null) {
      setIconModeFromStyle(settingsRepo.currentSettings.trayIconStyle);
      _menuStyle = settingsRepo.currentSettings.menuBarStyle;
      // Older builds saved companion + 'icon'; companion owns the icon then.
      if (_iconMode == TrayIconMode.companion && _menuStyle == 'icon') {
        _menuStyle = 'companion';
      }
    }

    final supportDir = await getApplicationSupportDirectory();
    final defaultFile = p.join(supportDir.path, 'bm_tray_default.png');
    try {
      final f = File(defaultFile);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}

    try {
      _defaultIconPath = await PetAssetLoader.extractAndWhitenAsset(
        AppConstants.trayIconPath,
        defaultFile,
      );
    } catch (_) {
      _defaultIconPath = AppConstants.trayIconPath;
    }

    _defaultIconPath ??= defaultFile;

    await _applyIcon();
    await _buildMenu();

    // Perform cleanup and frame extraction in background to avoid blocking main isolate startup
    unawaited(_initializeFramesInBackground());

    _logger.info('Tray manager initialized (mode: $_iconMode)');

    sl<EventBus>().stream.listen((event) {
      if (event is MeetingDetectedEvent) {
        _isMeetingActive = event.isActive;
        _scheduleMenuRebuild();
      }
    });
  }

  Future<void> _initializeFramesInBackground() async {
    // Rendering pet frames is CPU heavy; let the first dashboard frame land.
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(seconds: 2));
    try {
      final supportDir = await getApplicationSupportDirectory();
      if (supportDir.existsSync()) {
        final list = supportDir.listSync();
        for (final file in list) {
          if (file is File) {
            final filename = p.basename(file.path);
            // Only delete icon frame caches, never touch database or metadata
            if (filename.startsWith('bm_pframe_') ||
                filename.startsWith('bm_ccat_') ||
                filename.startsWith('bm_tray_')) {
              file.deleteSync();
            }
          }
        }
      }
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }

    await _extractIcons();
    _currentFrameIndex = 0;
    _updateTimerSpeed();
    await _applyIcon();
  }

  void setMenuBarController(MenuBarController controller) {
    _menuBarController = controller;
  }

  Future<void> updateSelectedBreed(String themeId) async {
    _logger.info('Updating tray icons to selected breed: $themeId');
    await _extractIcons();
    _currentFrameIndex = 0;
    _updateTimerSpeed();
    await _applyIcon();
  }

  Future<void> _extractIcons() async {
    final supportDir = await getApplicationSupportDirectory();

    _baseIcon = null;
    final defaultFile = p.join(supportDir.path, 'bm_tray_default.png');
    try {
      _defaultIconPath = await PetAssetLoader.extractAndWhitenAsset(
        AppConstants.trayIconPath,
        defaultFile,
      );
    } catch (_) {
      _defaultIconPath = AppConstants.trayIconPath;
    }

    if (_defaultIconPath == null || _defaultIconPath!.isEmpty) {
      _defaultIconPath = defaultFile;
    }

    if (_defaultIconPath != null) {
      debugPrint(
        '[Tray] Default icon path: $_defaultIconPath (Exists: ${File(_defaultIconPath!).existsSync() || !_defaultIconPath!.startsWith('/')})',
      );
    }

    final settingsRepo = _settingsRepo;
    final selectedThemeId =
        settingsRepo?.currentSettings.companionPetTheme ?? 'cat';
    final theme = PetTheme.getTheme(selectedThemeId);

    _stateFramePaths.clear();
    _avatarFrames = null;
    _lastAvatarKey = null;
    if (theme.isAvatar) {
      try {
        AvatarDefinition? def = theme.avatarDefinition;
        final raw = settingsRepo?.currentSettings.companionAvatarDefinition;
        if (raw != null && raw.isNotEmpty) {
          def = AvatarDefinition.fromJson(
            jsonDecode(raw) as Map<String, dynamic>,
          );
        }
        if (def != null) _avatarFrames = await TrayAvatarRenderer.render(def);
      } catch (e, st) {
        ErrorHandler().handleError(e, st);
      }
    }

    for (final state in [
      PetAnimationState.idle,
      PetAnimationState.sleep,
      PetAnimationState.excited,
      PetAnimationState.notification,
    ]) {
      try {
        final config = theme.animations[state];
        int frameCount = 1;
        if (config is AnimationRowConfig) {
          frameCount = config.frameCount;
        } else if (config is SeparateAnimationConfig) {
          frameCount = config.frameCount;
        }

        final List<String> paths = [];
        for (int i = 0; i < frameCount; i++) {
          final path = await PetAssetLoader.extractPetFramePath(
            theme: theme,
            state: state,
            frameIndex: i,
          );
          if (path.isNotEmpty) {
            paths.add(path);
          }
        }

        if (paths.isNotEmpty) {
          _stateFramePaths[state] = paths;
        } else {
          // Fallback to the first frame of the idle animation for the selected theme
          String fallbackPath = '';
          if (state != PetAnimationState.idle) {
            fallbackPath = await PetAssetLoader.extractPetFramePath(
              theme: theme,
              state: PetAnimationState.idle,
              frameIndex: 0,
            );
          }
          if (fallbackPath.isNotEmpty) {
            _stateFramePaths[state] = [fallbackPath];
          } else if (_defaultIconPath != null) {
            _stateFramePaths[state] = [_defaultIconPath!];
          }
        }
      } catch (e) {
        _logger.error('Failed to extract companion state ${state.name}: $e');
        _stateFramePaths[state] = [_defaultIconPath!];
      }
    }
  }

  String? _windowsIcoPath;

  Future<void> _resolveWindowsIcoPath() async {
    if (_windowsIcoPath != null) return;
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final icoPath = p.join(exeDir, 'app_icon.ico');
    if (File(icoPath).existsSync()) {
      _windowsIcoPath = icoPath;
    }
  }

  Future<void> _applyWindowsIcon() async {
    try {
      await _resolveWindowsIcoPath();
      if (_windowsIcoPath != null) {
        await trayManager.setIcon(_windowsIcoPath!);
      }
    } catch (e) {
      _logger.error('Failed to set Windows tray icon: $e');
    }
  }

  PetAnimationState _determineActiveState() {
    final state = _timerEngine?.state;
    if (state == TimerState.breakActive) {
      return PetAnimationState.notification;
    } else if (state == TimerState.paused) {
      return PetAnimationState.sleep;
    } else if (_isActionActive) {
      return PetAnimationState.excited;
    } else {
      return PetAnimationState.idle;
    }
  }

  Future<void> _applyIcon() async {
    // Windows tray requires .ico files — LoadImage cannot load .png
    if (Platform.isWindows) {
      await _applyWindowsIcon();
      return;
    }
    if (_usesDrawnIcon) {
      await _applyDrawnIcon();
      return;
    }
    try {
      String? path;
      switch (_iconMode) {
        case TrayIconMode.companion:
          final activeState = _determineActiveState();
          final avatar = _avatarFrames?[activeState];
          if (avatar != null && avatar.isNotEmpty) {
            final idx = _currentFrameIndex % avatar.length;
            final key = '${activeState.name}:$idx';
            if (key != _lastAvatarKey) {
              _lastAvatarKey = key;
              await _setTrayIconBytes(avatar[idx]);
              if (_currentTitle.isNotEmpty && Platform.isMacOS) {
                await trayManager.setTitle(_currentTitle);
              }
            }
            return;
          }
          final paths = _stateFramePaths[activeState] ?? [];
          if (paths.isNotEmpty) {
            final safeIndex = _currentFrameIndex % paths.length;
            path = paths[safeIndex];
          } else {
            path = _defaultIconPath;
          }
          if (path != null &&
              (path.startsWith('assets/') || File(path).existsSync())) {
            await _setTrayIconSafe(path, isTemplate: true);
          } else if (_defaultIconPath != null &&
              (_defaultIconPath!.startsWith('assets/') ||
                  File(_defaultIconPath!).existsSync())) {
            _logger.warning(
              'Missing primary tray icon asset: $path. Using fallback.',
            );
            await _setTrayIconSafe(_defaultIconPath!, isTemplate: true);
          } else {
            _logger.warning(
              'Missing both primary and fallback tray icon assets: $path, $_defaultIconPath',
            );
          }
          break;
        case TrayIconMode.defaultIcon:
        case TrayIconMode.minimal:
        case TrayIconMode.countdownOnly:
          if (_defaultIconPath != null) {
            await _setTrayIconSafe(_defaultIconPath!, isTemplate: true);
          }
          break;
      }

      bool isPathValid = false;
      if (path != null) {
        if (!path.startsWith('assets/')) {
          final file = File(path);
          if (file.existsSync() && file.lengthSync() > 0) {
            isPathValid = true;
          } else {
            _logger.warning('Tray icon file at $path is missing or empty.');
          }
        } else {
          isPathValid = true; // Asset paths are validated by Flutter bundle
        }
      }

      if (isPathValid && path != _lastAppliedIconPath) {
        _lastAppliedIconPath = path;
        await _setTrayIconSafe(path!, isTemplate: true);

        // On macOS, setting the icon sometimes clears the title depending on implementation.
        if (_currentTitle.isNotEmpty) {
          if (Platform.isMacOS) {
            await trayManager.setTitle(_currentTitle);
          }
        }
      } else if (!isPathValid && _defaultIconPath != null) {
        if (_lastAppliedIconPath != _defaultIconPath) {
          _lastAppliedIconPath = _defaultIconPath;
          await _setTrayIconSafe(_defaultIconPath!, isTemplate: true);
        }
      }
    } catch (e) {
      _logger.error('Failed to set tray icon: $e');
    }
  }

  Future<void> _setTrayIconSafe(String path, {bool isTemplate = true}) async {
    try {
      if (Platform.isMacOS) {
        Uint8List bytes;
        if (!path.startsWith('assets/')) {
          final file = File(path);
          if (await file.exists()) {
            bytes = await file.readAsBytes();
          } else {
            _logger.error('Tray icon file not found on disk: $path');
            return;
          }
        } else {
          final byteData = await rootBundle.load(path);
          bytes = byteData.buffer.asUint8List();
        }

        final base64Icon = base64Encode(bytes);
        const channel = MethodChannel('tray_manager');
        final arguments = {
          'id': 'bm_tray_${DateTime.now().millisecondsSinceEpoch}',
          'iconPath': path,
          'base64Icon': base64Icon,
          'isTemplate': isTemplate,
          'iconPosition': 'left',
          'iconSize': 18,
        };
        await channel.invokeMethod('setIcon', arguments);
      } else {
        await trayManager.setIcon(path, isTemplate: isTemplate);
      }
    } catch (e) {
      _logger.error('Error in _setTrayIconSafe: $e');
    }
  }

  void _updateTimerSpeed() {
    _animTimer?.cancel();
    if (_iconMode != TrayIconMode.companion) return;
    if (Platform.isWindows) return; // Windows uses static .ico, no animation

    final settingsRepo = _settingsRepo;
    final selectedThemeId =
        settingsRepo?.currentSettings.companionPetTheme ?? 'cat';
    final theme = PetTheme.getTheme(selectedThemeId);
    final activeState = _determineActiveState();
    final config = theme.animations[activeState];
    double stepTime = 0.2;
    if (config is AnimationRowConfig) {
      stepTime = config.stepTime;
    } else if (config is SeparateAnimationConfig) {
      stepTime = config.stepTime;
    }

    // Clamp to a safe minimum of 120ms to protect macOS system tray resource consumption
    final ms = _avatarFrames != null
        ? switch (_determineActiveState()) {
            PetAnimationState.sleep => 300,
            PetAnimationState.excited => 110,
            _ => 150,
          }
        : (stepTime * 1000).toInt().clamp(120, 1000);
    _animTimer = Timer.periodic(Duration(milliseconds: ms), (_) {
      _advanceFrame();
    });
  }

  void _advanceFrame() {
    final activeState = _determineActiveState();
    final count =
        _avatarFrames?[activeState]?.length ??
        _stateFramePaths[activeState]?.length ??
        0;
    if (count == 0) {
      _applyIcon();
      return;
    }
    _currentFrameIndex = (_currentFrameIndex + 1) % count;
    _applyIcon();
  }

  void setBreakActive(bool active) {
    // This method is now effectively a trigger for rebuild since _isBreakActive is gone
    _currentFrameIndex = 0;
    _updateTimerSpeed();
    _applyIcon();
    _scheduleMenuRebuild();
  }

  void triggerActionAnimation() {
    if (_iconMode != TrayIconMode.companion) return;

    _actionAnimTimer?.cancel();
    _isActionActive = true;
    _currentFrameIndex = 0;
    _updateTimerSpeed();
    _applyIcon();

    _actionAnimTimer = Timer(const Duration(milliseconds: 1200), () {
      _isActionActive = false;
      _currentFrameIndex = 0;
      _updateTimerSpeed();
      _applyIcon();
    });
  }

  /// Switches the menu bar style and plays a short sweep-in so the change is
  /// visible immediately.
  void setMenuStyle(String style) {
    if (_menuStyle == style) return;
    _menuStyle = style;
    if (style != 'countdown') unawaited(setTrayTitle(''));
    _lastDrawnKey = null;
    _lastAvatarKey = null;
    _lastAppliedIconPath = null;
    _progressAnimTimer?.cancel();
    _pulseTimer?.cancel();
    if (!_usesDrawnIcon) {
      _applyIcon();
      return;
    }
    // Slow breathing pulse keeps the icon alive between progress updates.
    _startPulse();
    _shownProgress = 0;
    _animateProgressTo(_progress, const Duration(milliseconds: 1800));
  }

  /// [fraction] is 0..1 of the current work interval (or break) elapsed.
  void updateProgress(double fraction, {bool onBreak = false}) {
    _progress = fraction.clamp(0.0, 1.0);
    if (_onBreak != onBreak) {
      _onBreak = onBreak;
      _lastDrawnKey = null;
    }
    if (!_usesDrawnIcon) return;
    if (_progressAnimTimer?.isActive ?? false) return;
    _animateProgressTo(_progress, const Duration(milliseconds: 900));
  }

  void _startPulse() {
    _pulseTimer?.cancel();
    if (!_usesDrawnIcon) return;
    var tick = 0;
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      // Far from a break the pulse is purely decorative: redraw at half rate.
      tick++;
      if (!_onBreak && _progress < 0.7 && tick.isOdd) return;
      _pulse = (_pulse + 1 / 24) % 1.0;
      if (_progressAnimTimer?.isActive ?? false) return;
      _applyIcon();
    });
  }

  void _animateProgressTo(double target, Duration duration) {
    _progressAnimTimer?.cancel();
    final from = _shownProgress;
    if ((target - from).abs() < 0.005 && _menuStyle == 'progress') {
      _shownProgress = target;
      _applyIcon();
      return;
    }
    const tick = Duration(milliseconds: 60);
    final steps = math.max(1, duration.inMilliseconds ~/ tick.inMilliseconds);
    var i = 0;
    _progressAnimTimer = Timer.periodic(tick, (t) {
      i++;
      final eased = Curves.easeInOutCubic.transform(
        (i / steps).clamp(0.0, 1.0),
      );
      _shownProgress = from + (target - from) * eased;
      _applyIcon();
      if (i >= steps) t.cancel();
    });
  }

  /// Calm green early on, amber as the break nears, red when it is due.
  /// While a break is running the icon turns blue.
  Color _accent(double progress) {
    if (_onBreak) return const Color(0xFF4DA3FF);
    if (progress < 0.5) {
      return Color.lerp(
        const Color(0xFF34C759),
        const Color(0xFFFFCC00),
        progress / 0.5,
      )!;
    }
    return Color.lerp(
      const Color(0xFFFFCC00),
      const Color(0xFFFF453A),
      (progress - 0.5) / 0.5,
    )!;
  }

  Future<void> _applyDrawnIcon() async {
    final q = (_shownProgress * 120).round();
    final pulseStep = (_pulse * 24).floor();
    final key = '$_menuStyle:$q:$pulseStep:$_onBreak';
    if (key == _lastDrawnKey) return;
    _lastDrawnKey = key;
    try {
      final bytes = _drawnCache[key] ??= await _renderIcon(
        q / 120,
        pulseStep / 24,
      );
      if (_drawnCache.length > 600) _drawnCache.clear();
      await _setTrayIconBytes(bytes);
      if (_currentTitle.isNotEmpty && Platform.isMacOS) {
        await trayManager.setTitle(_currentTitle);
      }
    } catch (e) {
      _logger.error('Failed to draw tray icon: $e');
    }
  }

  ui.Image? _baseIcon;

  Future<ui.Image?> _loadBaseIcon() async {
    if (_baseIcon != null) return _baseIcon;
    final path = _defaultIconPath;
    if (path == null) return null;
    try {
      final bytes = path.startsWith('assets/')
          ? (await rootBundle.load(path)).buffer.asUint8List()
          : await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      return _baseIcon = (await codec.getNextFrame()).image;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List> _renderIcon(double progress, double pulse) async {
    const size = 36.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));
    const center = Offset(size / 2, size / 2);
    const white = Color(0xFFFFFFFF);
    final color = _accent(progress);
    // Smooth breathing factor 0..1..0 over one pulse cycle.
    final breathe = (1 - math.cos(pulse * math.pi * 2)) / 2;
    final urgent = _onBreak || progress > 0.9;

    if (_menuStyle == 'icon') {
      // Status-coloured badge with the app mark inside. Works on light and
      // dark menu bars alike because the mark sits on a solid colour.
      final badge = 30.0 + breathe * 2.5;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: badge, height: badge),
        const Radius.circular(9),
      );
      canvas.drawRRect(
        rect.inflate(2),
        Paint()
          ..color = color.withValues(alpha: 0.25 + 0.2 * breathe)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(
            rect.outerRect.topLeft,
            rect.outerRect.bottomRight,
            [Color.lerp(color, white, 0.25)!, color],
          ),
      );
      final base = await _loadBaseIcon();
      if (base != null) {
        final mark = badge * 0.64;
        canvas.drawImageRect(
          base,
          Rect.fromLTWH(0, 0, base.width.toDouble(), base.height.toDouble()),
          Rect.fromCenter(center: center, width: mark, height: mark),
          Paint()
            ..filterQuality = FilterQuality.high
            ..colorFilter = const ColorFilter.mode(white, BlendMode.srcIn),
        );
      }
    } else if (_menuStyle == 'progress') {
      const stroke = 5.0;
      const radius = 13.0;
      final rect = Rect.fromCircle(center: center, radius: radius);
      // Neutral track reads on both light and dark menu bars.
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = const Color(0xFF8E8E93).withValues(alpha: 0.55),
      );
      final sweep = math.pi * 2 * math.max(progress, 0.02);
      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke + 5
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
          ..color = color.withValues(alpha: 0.25 + 0.2 * breathe),
      );
      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
      // Centre dot, kept well inside the ring.
      canvas.drawCircle(
        center,
        3 + breathe * (urgent ? 1.5 : 0.8),
        Paint()..color = color,
      );
    } else {
      // focusdot: a core, a clear gap, then ripples that fade outward.
      final core = 5.0 + 3.0 * progress + breathe * (urgent ? 1.2 : 0.6);
      const outer = 16.5;
      // Faint resting ring at the edge so the gap is always visible.
      canvas.drawCircle(
        center,
        outer,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = color.withValues(alpha: 0.35),
      );
      // One ripple travelling from just outside the core to the edge ring.
      final t = Curves.easeOut.transform(pulse);
      final rippleR = core + 4 + t * (outer - core - 6);
      canvas.drawCircle(
        center,
        rippleR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: 0.7 * (1 - t)),
      );
      canvas.drawCircle(
        center,
        core + 1.5,
        Paint()
          ..color = color.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
      canvas.drawCircle(
        center,
        core,
        Paint()
          ..shader = ui.Gradient.radial(
            center.translate(-core / 3, -core / 3),
            core * 1.5,
            [Color.lerp(color, white, 0.45)!, color],
          ),
      );
    }

    final image = await recorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<void> _setTrayIconBytes(Uint8List bytes) async {
    if (Platform.isMacOS) {
      await const MethodChannel('tray_manager').invokeMethod('setIcon', {
        'id': 'bm_tray_${DateTime.now().millisecondsSinceEpoch}',
        'iconPath': '',
        'base64Icon': base64Encode(bytes),
        'isTemplate': false,
        'iconPosition': 'left',
        'iconSize': 18,
      });
    } else {
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, 'bm_tray_drawn.png'));
      await file.writeAsBytes(bytes, flush: true);
      await trayManager.setIcon(file.path, isTemplate: false);
    }
  }

  void setIconMode(TrayIconMode mode) {
    _iconMode = mode;
    _lastAvatarKey = null;
    _lastDrawnKey = null;
    _lastAppliedIconPath = null;
    _animTimer?.cancel();
    if (mode == TrayIconMode.companion) {
      _currentFrameIndex = 0;
      _updateTimerSpeed();
    } else {
      _applyIcon();
    }
  }

  void setIconModeFromStyle(String style) {
    switch (style) {
      case 'companion':
      case 'cat':
        setIconMode(TrayIconMode.companion);
        break;
      case 'minimal':
        setIconMode(TrayIconMode.minimal);
        break;
      case 'countdown':
      case 'countdown only':
        setIconMode(TrayIconMode.countdownOnly);
        break;
      case 'default':
      default:
        setIconMode(TrayIconMode.defaultIcon);
        break;
    }
  }

  bool _isRebuildingMenu = false;
  bool _menuRebuildPending = false;

  void _scheduleMenuRebuild() {
    if (_isRebuildingMenu) {
      _menuRebuildPending = true;
      return;
    }

    _isRebuildingMenu = true;
    _buildMenu().then((_) {
      _isRebuildingMenu = false;
      if (_menuRebuildPending) {
        _menuRebuildPending = false;
        _scheduleMenuRebuild();
      }
    });
  }

  Future<void> _buildMenu() async {
    String statusLabel = 'BreakMate';

    final state = _timerEngine?.state;
    final isBreakActive = state == TimerState.breakActive;
    final isPaused = state == TimerState.paused;

    if (_timerEngine != null) {
      if (_isMeetingActive) {
        statusLabel = 'In a Meeting (Paused)';
      } else if (isBreakActive) {
        statusLabel = 'On Break';
      } else if (isPaused) {
        statusLabel = 'Timer Paused';
      } else if (state == TimerState.running) {
        statusLabel = 'Timer Running';
      } else {
        statusLabel = 'Timer Idle';
      }
    }

    final List<MenuItem> items = [];

    items.add(MenuItem(label: statusLabel, disabled: true));
    items.add(MenuItem.separator());

    if (isBreakActive) {
      final isStrict = _settingsRepo?.currentSettings.strictMode ?? false;
      items.addAll([
        MenuItem(key: 'complete_break', label: 'Complete Break'),
        MenuItem(
          key: 'skip_current_break',
          label: 'Skip Break',
          disabled: isStrict,
        ),
        MenuItem(
          key: 'postpone_break',
          label: 'Postpone Break (2 min)',
          disabled: isStrict,
        ),
        MenuItem.separator(),
      ]);
    } else {
      items.addAll([
        MenuItem(
          key: 'toggle_pause',
          label: isPaused ? 'Resume Timer' : 'Pause Timer',
        ),
        MenuItem(key: 'take_break', label: 'Instant Break'),
        MenuItem(key: 'skip_next', label: 'Skip Next Break'),
        MenuItem.separator(),
      ]);
    }

    items.addAll([
      MenuItem(key: 'open_app', label: 'Open Dashboard'),
      MenuItem(key: 'open_companion', label: 'Companion Settings'),
      MenuItem(key: 'open_notifications', label: 'Notification Settings'),
      MenuItem(key: 'open_stats', label: 'View Statistics'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: 'Quit BreakMate'),
    ]);

    final menu = Menu(items: items);
    await trayManager.setContextMenu(menu);
  }

  void _handleAction(String action) {
    _logger.info('Tray action: $action');
    triggerActionAnimation();
    final controller = _menuBarController ?? sl<MenuBarController>();
    controller.handleAction(action);
  }

  void setDependencies(
    TimerEngine timerEngine,
    BreakController breakController,
  ) {
    _timerEngine?.removeListener(_onTimerChanged);
    _breakController?.removeListener(_onTimerChanged);
    _timerEngine = timerEngine;
    _breakController = breakController;
    timerEngine.addListener(_onTimerChanged);
    breakController.addListener(_onTimerChanged);

    // Initial sync
    _onTimerChanged();
  }

  TimerState? _lastState;

  void _onTimerChanged() {
    final timerEngine = _timerEngine;
    if (timerEngine != null) {
      if (timerEngine.systemSleepPaused) {
        _animTimer?.cancel();
        _actionAnimTimer?.cancel();
        _pulseTimer?.cancel();
        _lastState = null; // Reset to force rebuild on wake
        return;
      }
      final state = timerEngine.state;
      if (_lastState != state) {
        _lastState = state;
        _currentFrameIndex = 0;
        _updateTimerSpeed();
        if (!(_pulseTimer?.isActive ?? false)) _startPulse();
        _applyIcon();
        _scheduleMenuRebuild();
      }
    }
  }

  void updatePauseState(bool isPaused) {
    // This is now handled via the TimerEngine listener, but we can trigger a check here for safety
    _onTimerChanged();
  }

  Future<void> setTrayTitle(String title) async {
    // Only the countdown style shows text; focus dot / progress are icon-only.
    if (_menuStyle != 'countdown') title = '';
    _currentTitle = title;
    try {
      if (Platform.isMacOS) {
        await trayManager.setTitle(title);
      } else if (Platform.isWindows && title.isNotEmpty) {
        // Windows doesn't support tray title — show countdown in tooltip instead
        final tooltip = title.isNotEmpty && _currentTooltip.isNotEmpty
            ? '$title — $_currentTooltip'
            : title.isNotEmpty
            ? title
            : _currentTooltip;
        await trayManager.setToolTip(tooltip);
      }
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }
  }

  String _currentTooltip = '';

  Future<void> setTooltip(String tooltip) async {
    _currentTooltip = tooltip;
    try {
      if (Platform.isWindows && _currentTitle.isNotEmpty) {
        await trayManager.setToolTip('$_currentTitle — $tooltip');
      } else {
        await trayManager.setToolTip(tooltip);
      }
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }
  }

  @override
  void onTrayIconMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconMouseUp() {}

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final key = menuItem.key;
    if (key != null) {
      _handleAction(key);
    }
  }

  @override
  void didChangePlatformBrightness() {
    _logger.info('Platform brightness changed, regenerating tray icons...');
    _drawnCache.clear();
    _lastDrawnKey = null;
    _extractIcons().then((_) {
      _applyIcon();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _animTimer?.cancel();
      _actionAnimTimer?.cancel();
      _pulseTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _updateTimerSpeed();
      _startPulse();
    }
  }

  void dispose() {
    _animTimer?.cancel();
    _progressAnimTimer?.cancel();
    _pulseTimer?.cancel();
    _timerEngine?.removeListener(_onTimerChanged);
    _breakController?.removeListener(_onTimerChanged);
    trayManager.removeListener(this);
    WidgetsBinding.instance.removeObserver(this);
  }
}
