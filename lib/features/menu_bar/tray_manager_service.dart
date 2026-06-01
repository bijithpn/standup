import 'dart:async';
import 'dart:convert';
import 'dart:io';
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

enum TrayIconMode { defaultIcon, companion, minimal, countdownOnly }

class TrayManagerService with TrayListener, WidgetsBindingObserver {
  final AppLogger _logger = AppLogger();
  bool _isPaused = false;
  bool _isMeetingActive = false;
  TrayIconMode _iconMode = TrayIconMode.companion;

  Timer? _animTimer;
  bool _isBreakActive = false;
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

    // Eagerly sync style from SettingsRepository before icon extraction/load
    final settingsRepo = sl<SettingsRepository>();
    setIconModeFromStyle(settingsRepo.currentSettings.trayIconStyle);

    final supportDir = await getApplicationSupportDirectory();
    final defaultFile = p.join(supportDir.path, 'bm_tray_default.png');

    // Show initial icon and menu as fast as possible
    try {
      _defaultIconPath = await PetAssetLoader.extractAndWhitenAsset(
        'assets/icons/app_icon.jpeg',
        defaultFile,
      );
    } catch (_) {
      // Fallback to asset if extraction fails
      _defaultIconPath = 'assets/icons/app_icon.jpeg';
    }
    
    _defaultIconPath ??= defaultFile;
    
    await _applyIcon();
    await _buildMenu();

    // Perform cleanup and frame extraction in background to avoid blocking main isolate startup
    unawaited(_initializeFramesInBackground());

    _logger.info('Tray manager initialized (mode: $_iconMode)');

    // Listen for meeting events from the main isolate's event bus
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
                filename.startsWith('bm_ccat_')) {
              file.deleteSync();
            }
          }
        }
      }
    } catch (_) {}

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
        'assets/icons/app_icon.jpeg',
        defaultFile,
      );
    } catch (_) {
      _defaultIconPath = 'assets/icons/app_icon.jpeg';
    }

    if (_defaultIconPath == null || _defaultIconPath!.isEmpty) {
      _defaultIconPath = defaultFile;
    }

    // Use raw absolute paths for tray_manager
    if (_defaultIconPath != null) {
      debugPrint('[Tray] Default icon path: $_defaultIconPath (Exists: ${File(_defaultIconPath!).existsSync() || !_defaultIconPath!.startsWith('/')})');
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
          // Fallback to static asset if frame extraction yielded nothing
          String iconName;
          switch (state) {
            case PetAnimationState.sleep:
              iconName = 'sleeping';
              break;
            case PetAnimationState.excited:
              iconName = 'stretch';
              break;
            case PetAnimationState.notification:
              iconName = 'alert';
              break;
            case PetAnimationState.idle:
            default:
              iconName = 'idle';
              break;
          }
          final fallbackFile = p.join(supportDir.path, 'bm_cat_${state.name}.png');
          final fallbackPath = await PetAssetLoader.extractAndWhitenAsset(
            'assets/icons/cat/cat_$iconName.png',
            fallbackFile,
          );
          if (fallbackPath.isNotEmpty) {
            _stateFramePaths[state] = [fallbackPath];
          } else {
            // Ultimate fallback to bundled asset
            _stateFramePaths[state] = ['assets/icons/cat/cat_$iconName.png'];
          }
        }
      } catch (e) {
        _logger.error('Failed to extract companion state ${state.name}: $e');
        _stateFramePaths[state] = [_defaultIconPath!];
      }
    }
  }

  PetAnimationState _determineActiveState() {
    if (_isBreakActive) {
      return PetAnimationState.notification;
    } else if (_isPaused) {
      return PetAnimationState.sleep;
    } else if (_isActionActive) {
      return PetAnimationState.excited;
    } else {
      return PetAnimationState.idle;
    }
  }

  Future<void> _applyIcon() async {
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
          if (path != null && (path.startsWith('assets/') || File(path).existsSync())) {
            await _setTrayIconSafe(path, isTemplate: true);
          } else if (_defaultIconPath != null && (_defaultIconPath!.startsWith('assets/') || File(_defaultIconPath!).existsSync())) {
            _logger.warning('Missing primary tray icon asset: $path. Using fallback.');
            await _setTrayIconSafe(_defaultIconPath!, isTemplate: true);
          } else {
            _logger.warning('Missing both primary and fallback tray icon assets: $path, $_defaultIconPath');
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
        // Re-apply current title if it exists.
        if (_currentTitle.isNotEmpty) {
          await trayManager.setTitle(_currentTitle);
        }
      } else if (!isPathValid && _defaultIconPath != null) {
        // Fallback to default if primary failed
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
    if (_isBreakActive == active) return;
    _isBreakActive = active;
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

    if (_timerEngine != null) {
      if (_isMeetingActive) {
        statusLabel = 'In a Meeting (Paused)';
      } else if (_isBreakActive) {
        statusLabel = 'On Break';
      } else if (_isPaused) {
        statusLabel = 'Timer Paused';
      } else if (_timerEngine!.state == TimerState.running) {
        statusLabel = 'Timer Running';
      } else {
        statusLabel = 'Timer Idle';
      }
    }

    final List<MenuItem> items = [];

    items.add(MenuItem(label: statusLabel, disabled: true));
    items.add(MenuItem.separator());

    if (_isBreakActive) {
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
          label: _isPaused ? 'Resume Timer' : 'Pause Timer',
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
    _scheduleMenuRebuild();
  }

  TimerState? _lastState;

  void _onTimerChanged() {
    final timerEngine = _timerEngine;
    if (timerEngine != null) {
      final state = timerEngine.state;
      if (_lastState != state) {
        _lastState = state;
        _isPaused = state == TimerState.paused;
        _isBreakActive = state == TimerState.breakActive;
        _currentFrameIndex = 0;
        _updateTimerSpeed();
        _applyIcon();
        _scheduleMenuRebuild();
      }
    }
  }

  void updatePauseState(bool isPaused) {
    if (_isPaused == isPaused) return;
    _isPaused = isPaused;
    if (_iconMode == TrayIconMode.companion) {
      _currentFrameIndex = 0;
      _updateTimerSpeed();
      _applyIcon();
    }
    _scheduleMenuRebuild();
  }

  Future<void> setTrayTitle(String title) async {
    _currentTitle = title;
    try {
      await trayManager.setTitle(title);
    } catch (_) {}
  }

  Future<void> setTooltip(String tooltip) async {
    try {
      await trayManager.setToolTip(tooltip);
    } catch (_) {}
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
