import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:flutter/widgets.dart';
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

  Future<void> init() async {
    trayManager.addListener(this);
    WidgetsBinding.instance.addObserver(this);

    // Eagerly sync style from SettingsRepository before icon extraction/load
    final settingsRepo = sl<SettingsRepository>();
    setIconModeFromStyle(settingsRepo.currentSettings.trayIconStyle);

    // Clean up older cached white/legacy tray icons from system temp directory
    try {
      final tempDir = Directory.systemTemp;
      if (tempDir.existsSync()) {
        final list = tempDir.listSync();
        for (final file in list) {
          if (file is File) {
            final filename = file.path.split(Platform.pathSeparator).last;
            if (filename.startsWith('bm_')) {
              file.deleteSync();
            }
          }
        }
      }
    } catch (_) {}

    await _extractIcons();
    await _applyIcon();
    await _buildMenu();
    _startCatAnimation();
    _logger.info('Tray manager initialized (mode: $_iconMode)');

    // Listen for meeting events from the main isolate's event bus
    sl<EventBus>().stream.listen((event) {
      if (event is MeetingDetectedEvent) {
        _isMeetingActive = event.isActive;
        _scheduleMenuRebuild();
      }
    });
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
    final tempDir = Directory.systemTemp;
    final isDark =
        ui.PlatformDispatcher.instance.platformBrightness == ui.Brightness.dark;
    final themeSuffix = isDark ? '_dark' : '_light';

    final defaultFile =
        '${tempDir.path}/bm_ctray_default${themeSuffix}Template@2x.png';
    _defaultIconPath = await PetAssetLoader.extractAndWhitenAsset(
      'assets/icons/tray_icon.png',
      defaultFile,
    );
    if (_defaultIconPath == null || _defaultIconPath!.isEmpty) {
      _defaultIconPath = defaultFile;
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
          final fallbackFile =
              '${tempDir.path}/bm_ccat_${state.name}${themeSuffix}Template@2x.png';
          final fallbackPath = await PetAssetLoader.extractAndWhitenAsset(
            'assets/icons/cat/cat_$iconName.png',
            fallbackFile,
          );
          if (fallbackPath.isNotEmpty) {
            _stateFramePaths[state] = [fallbackPath];
          } else {
            _stateFramePaths[state] = [_defaultIconPath!];
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
      switch (_iconMode) {
        case TrayIconMode.companion:
          final activeState = _determineActiveState();
          final paths = _stateFramePaths[activeState] ?? [];
          String? path;
          if (paths.isNotEmpty) {
            final safeIndex = _currentFrameIndex % paths.length;
            path = paths[safeIndex];
          } else {
            path = _defaultIconPath;
          }
          if (path != null) await trayManager.setIcon(path, isTemplate: true);
          break;
        case TrayIconMode.defaultIcon:
        case TrayIconMode.minimal:
        case TrayIconMode.countdownOnly:
          if (_defaultIconPath != null) {
            await trayManager.setIcon(_defaultIconPath!, isTemplate: true);
          }
          break;
      }
    } catch (e) {
      _logger.error('Failed to set tray icon: $e');
    }
  }

  void _startCatAnimation() {
    _currentFrameIndex = 0;
    _updateTimerSpeed();
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
      case 'minimal':
        setIconMode(TrayIconMode.minimal);
      case 'countdown':
      case 'countdown only':
        setIconMode(TrayIconMode.countdownOnly);
      case 'default':
      default:
        setIconMode(TrayIconMode.defaultIcon);
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
    if (state == AppLifecycleState.hidden || state == AppLifecycleState.paused) {
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
