import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
import 'controllers/menu_bar_controller.dart';
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

  final Map<PetAnimationState, List<String>> _stateFramePaths = {};
  String? _defaultIconPath;
  String? _lastAppliedIconPath;
  String _currentTitle = '';

  Future<void> init() async {
    trayManager.addListener(this);
    WidgetsBinding.instance.addObserver(this);

    final settingsRepo = sl<SettingsRepository>();
    setIconModeFromStyle(settingsRepo.currentSettings.trayIconStyle);

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

    final settingsRepo = sl<SettingsRepository>();
    final selectedThemeId = settingsRepo.currentSettings.companionPetTheme;
    final theme = PetTheme.getTheme(selectedThemeId);

    _stateFramePaths.clear();

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
    try {
      String? path;
      switch (_iconMode) {
        case TrayIconMode.companion:
          final activeState = _determineActiveState();
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

    final settingsRepo = sl<SettingsRepository>();
    final selectedThemeId = settingsRepo.currentSettings.companionPetTheme;
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
    final ms = (stepTime * 1000).toInt().clamp(120, 1000);
    _animTimer = Timer.periodic(Duration(milliseconds: ms), (_) {
      _advanceFrame();
    });
  }

  void _advanceFrame() {
    final activeState = _determineActiveState();
    final paths = _stateFramePaths[activeState] ?? [];
    if (paths.isEmpty) {
      _applyIcon();
      return;
    }
    _currentFrameIndex = (_currentFrameIndex + 1) % paths.length;
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

  void setIconMode(TrayIconMode mode) {
    _iconMode = mode;
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
      final isStrict = sl<SettingsRepository>().currentSettings.strictMode;
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
        _lastState = null; // Reset to force rebuild on wake
        return;
      }
      final state = timerEngine.state;
      if (_lastState != state) {
        _lastState = state;
        _currentFrameIndex = 0;
        _updateTimerSpeed();
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
    } else if (state == AppLifecycleState.resumed) {
      _updateTimerSpeed();
    }
  }

  void dispose() {
    _animTimer?.cancel();
    _timerEngine?.removeListener(_onTimerChanged);
    _breakController?.removeListener(_onTimerChanged);
    trayManager.removeListener(this);
    WidgetsBinding.instance.removeObserver(this);
  }
}
