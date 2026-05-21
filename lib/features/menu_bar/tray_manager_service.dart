import 'dart:async';
import 'dart:io';
import 'package:tray_manager/tray_manager.dart';
import 'package:standup/app/dependency_injection.dart';
import 'package:standup/core/utils/logger.dart';
import 'package:standup/core/services/timer_engine.dart';
import 'package:standup/features/break_system/application/break_controller.dart';
import 'package:standup/features/companion/data/cat_asset_loader.dart';
import 'package:standup/features/companion/domain/cat_theme.dart';
import 'package:standup/features/companion/domain/cat_animation_state.dart';
import 'package:standup/features/companion/domain/animation_row_config.dart';
import 'package:standup/features/settings/settings_repository.dart';
import 'controllers/menu_bar_controller.dart';

enum TrayIconMode { defaultIcon, companion, minimal, countdownOnly }

class TrayManagerService with TrayListener {
  final AppLogger _logger = AppLogger();
  bool _isPaused = false;
  TrayIconMode _iconMode = TrayIconMode.companion;

  Timer? _animTimer;
  bool _isBreakActive = false;
  bool _isActionActive = false;
  Timer? _actionAnimTimer;
  int _currentFrameIndex = 0;

  TimerEngine? _timerEngine;
  BreakController? _breakController;
  MenuBarController? _menuBarController;

  final Map<CatAnimationState, List<String>> _stateFramePaths = {};
  String? _defaultIconPath;

  Future<void> init() async {
    trayManager.addListener(this);
    
    // Eagerly sync style from SettingsRepository before icon extraction/load
    final settingsRepo = sl<SettingsRepository>();
    setIconModeFromStyle(settingsRepo.currentSettings.trayIconStyle);
    
    await _extractIcons();
    await _applyIcon();
    await _buildMenu();
    _startCatAnimation();
    _logger.info('Tray manager initialized (mode: $_iconMode)');
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

    final defaultFile = '${tempDir.path}/bm_ctray_defaultTemplate@2x.png';
    _defaultIconPath = await CatAssetLoader.extractAndWhitenAsset(
      'assets/icons/tray_icon.png',
      defaultFile,
    );
    if (_defaultIconPath == null || _defaultIconPath!.isEmpty) {
      _defaultIconPath = defaultFile;
    }

    final settingsRepo = sl<SettingsRepository>();
    final selectedThemeId = settingsRepo.currentSettings.companionCatTheme;
    final theme = CatTheme.getTheme(selectedThemeId);

    _stateFramePaths.clear();

    for (final state in [
      CatAnimationState.idle,
      CatAnimationState.sleep,
      CatAnimationState.excited,
      CatAnimationState.notification,
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
          final path = await CatAssetLoader.extractCatFramePath(
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
            case CatAnimationState.sleep:
              iconName = 'sleeping';
              break;
            case CatAnimationState.excited:
              iconName = 'stretch';
              break;
            case CatAnimationState.notification:
              iconName = 'alert';
              break;
            case CatAnimationState.idle:
            default:
              iconName = 'idle';
              break;
          }
          final fallbackFile = '${tempDir.path}/bm_ccat_${state.name}Template@2x.png';
          final fallbackPath = await CatAssetLoader.extractAndWhitenAsset(
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

  CatAnimationState _determineActiveState() {
    if (_isBreakActive) {
      return CatAnimationState.notification;
    } else if (_isPaused) {
      return CatAnimationState.sleep;
    } else if (_isActionActive) {
      return CatAnimationState.excited;
    } else {
      return CatAnimationState.idle;
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
          if (path != null) await trayManager.setIcon(path);
          break;
        case TrayIconMode.defaultIcon:
        case TrayIconMode.minimal:
        case TrayIconMode.countdownOnly:
          if (_defaultIconPath != null) {
            await trayManager.setIcon(_defaultIconPath!);
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
    final selectedThemeId = settingsRepo.currentSettings.companionCatTheme;
    final theme = CatTheme.getTheme(selectedThemeId);
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
    _isBreakActive = active;
    _currentFrameIndex = 0;
    _updateTimerSpeed();
    _applyIcon();
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

  Future<void> _buildMenu() async {
    String statusLabel = 'BreakMate';
    String nextBreakLabel = 'Next: --';
    
    if (_timerEngine != null) {
      final remaining = _timerEngine!.timeUntilNextShortBreak;
      final mins = remaining.inMinutes;
      final secs = (remaining.inSeconds % 60).toString().padLeft(2, '0');
      
      if (_isBreakActive) {
        statusLabel = 'On Break';
        final breakRemaining = _timerEngine!.countdownSeconds;
        final breakMins = breakRemaining ~/ 60;
        final breakSecs = (breakRemaining % 60).toString().padLeft(2, '0');
        nextBreakLabel = 'Time Remaining: $breakMins:$breakSecs';
      } else if (_isPaused) {
        statusLabel = 'Reminders Paused';
        nextBreakLabel = 'Timer is inactive';
      } else {
        statusLabel = 'Reminders Active';
        nextBreakLabel = 'Next Break: $mins:$secs';
      }
    }

    final List<MenuItem> items = [];

    items.add(MenuItem(label: statusLabel, disabled: true));
    items.add(MenuItem(label: nextBreakLabel, disabled: true));
    items.add(MenuItem.separator());

    if (_isBreakActive) {
      items.addAll([
        MenuItem(
          key: 'complete_break',
          label: 'Complete Break',
          onClick: _onMenuItemClick,
        ),
        MenuItem(
          key: 'skip_current_break',
          label: 'Skip Break',
          onClick: _onMenuItemClick,
        ),
        MenuItem(
          key: 'postpone_break',
          label: 'Postpone Break (2 min)',
          onClick: _onMenuItemClick,
        ),
        MenuItem.separator(),
      ]);
    } else {
      items.addAll([
        MenuItem(
          key: 'toggle_pause',
          label: _isPaused ? 'Resume Reminders' : 'Pause Reminders',
          onClick: _onMenuItemClick,
        ),
        MenuItem(
          key: 'take_break',
          label: 'Start Break Now',
          onClick: _onMenuItemClick,
        ),
        MenuItem(
          key: 'skip_next',
          label: 'Skip Next Break',
          onClick: _onMenuItemClick,
        ),
        MenuItem.separator(),
      ]);
    }

    items.addAll([
      MenuItem(
        key: 'open_dashboard',
        label: 'Open Dashboard',
        onClick: _onMenuItemClick,
      ),
      MenuItem(
        key: 'open_settings',
        label: 'Settings',
        onClick: _onMenuItemClick,
      ),
      MenuItem(
        key: 'open_flash',
        label: 'Flash Reminder',
        onClick: _onMenuItemClick,
      ),
      MenuItem(
        key: 'open_exercises',
        label: 'Exercises',
        onClick: _onMenuItemClick,
      ),
      MenuItem(
        key: 'open_stats',
        label: 'Statistics',
        onClick: _onMenuItemClick,
      ),
      MenuItem.separator(),
      MenuItem(
        key: 'posture_reminder',
        label: 'Posture Reminder',
        onClick: _onMenuItemClick,
      ),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: 'Quit BreakMate', onClick: _onMenuItemClick),
    ]);

    final menu = Menu(items: items);
    await trayManager.setContextMenu(menu);
  }

  void _onMenuItemClick(MenuItem menuItem) {
    if (menuItem.key != null) {
      _handleAction(menuItem.key!);
    }
  }

  void _handleAction(String action) {
    _logger.info('Tray action: $action');
    triggerActionAnimation();
    final controller = _menuBarController;
    if (controller == null) {
      _logger.error('No MenuBarController registered for action: $action');
      return;
    }
    controller.handleAction(action);
  }

  void setDependencies(TimerEngine timerEngine, BreakController breakController) {
    _timerEngine?.removeListener(_onTimerChanged);
    _breakController?.removeListener(_onTimerChanged);
    _timerEngine = timerEngine;
    _breakController = breakController;
    timerEngine.addListener(_onTimerChanged);
    breakController.addListener(_onTimerChanged);
    _buildMenu();
  }

  void _onTimerChanged() {
    _buildMenu();
  }

  void updatePauseState(bool isPaused) {
    _isPaused = isPaused;
    if (_iconMode == TrayIconMode.companion) {
      _currentFrameIndex = 0;
      _updateTimerSpeed();
      _applyIcon();
    }
    _buildMenu();
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

  void dispose() {
    _animTimer?.cancel();
    _timerEngine?.removeListener(_onTimerChanged);
    _breakController?.removeListener(_onTimerChanged);
    trayManager.removeListener(this);
  }
}
