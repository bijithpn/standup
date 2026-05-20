import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:standup/app/dependency_injection.dart';
import 'package:standup/core/utils/logger.dart';
import 'package:standup/core/services/timer_engine.dart';
import 'package:standup/features/break_system/application/break_controller.dart';
import 'package:standup/features/companion/data/cat_asset_loader.dart';
import 'package:standup/features/companion/domain/cat_theme.dart';
import 'package:standup/features/companion/domain/cat_animation_state.dart';
import 'package:standup/features/settings/settings_repository.dart';
import 'controllers/menu_bar_controller.dart';

enum TrayIconMode { defaultIcon, cat, minimal, countdownOnly }

enum _CatFrame { idle, blink, stretch, sleeping, alert }

class TrayManagerService with TrayListener {
  final AppLogger _logger = AppLogger();
  bool _isPaused = false;
  TrayIconMode _iconMode = TrayIconMode.cat;

  Timer? _animTimer;
  _CatFrame _catFrame = _CatFrame.idle;
  bool _isBreakActive = false;

  TimerEngine? _timerEngine;
  BreakController? _breakController;
  MenuBarController? _menuBarController;

  final Map<_CatFrame, String> _catIconPaths = {};
  String? _defaultIconPath;

  Future<void> init() async {
    trayManager.addListener(this);
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
    await _applyIcon();
  }

  Future<void> _extractIcons() async {
    final tempDir = Directory.systemTemp;

    final defaultBytes = await rootBundle.load('assets/icons/tray_icon.png');
    final defaultFile = File('${tempDir.path}/bm_tray_default.png');
    await defaultFile.writeAsBytes(defaultBytes.buffer.asUint8List());
    _defaultIconPath = defaultFile.path;

    final settingsRepo = sl<SettingsRepository>();
    final selectedThemeId = settingsRepo.currentSettings.companionCatTheme;
    final theme = CatTheme.getTheme(selectedThemeId);

    for (final frame in _CatFrame.values) {
      try {
        CatAnimationState state;
        int frameIndex = 0;
        switch (frame) {
          case _CatFrame.idle:
            state = CatAnimationState.idle;
            frameIndex = 0;
          case _CatFrame.blink:
            state = CatAnimationState.idle;
            frameIndex = 1;
          case _CatFrame.stretch:
            state = CatAnimationState.excited;
            frameIndex = 0;
          case _CatFrame.sleeping:
            state = CatAnimationState.sleep;
            frameIndex = 0;
          case _CatFrame.alert:
            state = CatAnimationState.notification;
            frameIndex = 0;
        }

        final path = await CatAssetLoader.extractCatFramePath(
          theme: theme,
          state: state,
          frameIndex: frameIndex,
        );

        if (path.isNotEmpty) {
          _catIconPaths[frame] = path;
        } else {
          final bytes = await rootBundle.load('assets/icons/cat/cat_${frame.name}.png');
          final file = File('${tempDir.path}/bm_cat_${frame.name}.png');
          await file.writeAsBytes(bytes.buffer.asUint8List());
          _catIconPaths[frame] = file.path;
        }
      } catch (e) {
        _logger.error('Failed to extract cat frame ${frame.name}: $e');
        _catIconPaths[frame] = _defaultIconPath!;
      }
    }
  }

  Future<void> _applyIcon() async {
    try {
      switch (_iconMode) {
        case TrayIconMode.cat:
          final path = _catIconPaths[_catFrame] ?? _defaultIconPath;
          if (path != null) await trayManager.setIcon(path);
        case TrayIconMode.defaultIcon:
        case TrayIconMode.minimal:
        case TrayIconMode.countdownOnly:
          if (_defaultIconPath != null) {
            await trayManager.setIcon(_defaultIconPath!);
          }
      }
    } catch (e) {
      _logger.error('Failed to set tray icon: $e');
    }
  }

  void _startCatAnimation() {
    _animTimer?.cancel();
    if (_iconMode != TrayIconMode.cat) return;

    _animTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      _advanceCatFrame();
    });
  }

  void _advanceCatFrame() {
    if (_isBreakActive) {
      _catFrame = _CatFrame.alert;
    } else if (_isPaused) {
      _catFrame = _CatFrame.sleeping;
    } else {
      switch (_catFrame) {
        case _CatFrame.idle:
          _catFrame = (DateTime.now().millisecond % 5 == 0)
              ? _CatFrame.blink
              : _CatFrame.idle;
        case _CatFrame.blink:
          _catFrame = _CatFrame.idle;
        case _CatFrame.stretch:
          _catFrame = _CatFrame.idle;
        case _CatFrame.sleeping:
          _catFrame = _CatFrame.sleeping;
        case _CatFrame.alert:
          _catFrame = _CatFrame.idle;
      }
    }
    _applyIcon();
  }

  void setBreakActive(bool active) {
    _isBreakActive = active;
    if (active) {
      _catFrame = _CatFrame.alert;
      _applyIcon();
    } else if (_iconMode == TrayIconMode.cat) {
      _catFrame = _isPaused ? _CatFrame.sleeping : _CatFrame.idle;
      _applyIcon();
    }
  }

  void triggerActionAnimation() {
    if (_iconMode != TrayIconMode.cat) return;
    
    final originalFrame = _catFrame;
    _catFrame = _CatFrame.stretch;
    _applyIcon();
    
    Timer(const Duration(milliseconds: 1200), () {
      if (!_isBreakActive && !_isPaused) {
        _catFrame = originalFrame;
        _applyIcon();
      }
    });
  }

  void setIconMode(TrayIconMode mode) {
    _iconMode = mode;
    _animTimer?.cancel();
    if (mode == TrayIconMode.cat) {
      _startCatAnimation();
    } else {
      _applyIcon();
    }
  }

  void setIconModeFromStyle(String style) {
    switch (style) {
      case 'cat':
        setIconMode(TrayIconMode.cat);
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
    _menuBarController?.handleAction(action);
  }

  void setDependencies(TimerEngine timerEngine, BreakController breakController) {
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
    if (_iconMode == TrayIconMode.cat) {
      _catFrame = isPaused ? _CatFrame.sleeping : _CatFrame.idle;
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
