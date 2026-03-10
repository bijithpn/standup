import 'dart:io';

import 'package:flutter/services.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:standup/core/utils/logger.dart';

typedef TrayMenuAction = void Function(String action);

class TrayManagerService with TrayListener {
  final AppLogger _logger = AppLogger();
  TrayMenuAction? onMenuAction;
  bool _isPaused = false;

  Future<void> init() async {
    trayManager.addListener(this);
    await _setupTrayIcon();
    await _buildMenu();
    _logger.info('Tray manager initialized');
  }

  Future<void> _setupTrayIcon() async {
    // Extract bundled asset to temp file for tray icon
    final byteData = await rootBundle.load('assets/icons/tray_icon.png');
    final tempDir = Directory.systemTemp;
    final iconFile = File('${tempDir.path}/breakloop_tray_icon.png');
    await iconFile.writeAsBytes(byteData.buffer.asUint8List());
    await trayManager.setIcon(iconFile.path);
  }

  Future<void> _buildMenu() async {
    final menu = Menu(items: [
        MenuItem(label: 'BreakLoop', disabled: true),
      MenuItem.separator(),
      MenuItem(
        key: 'toggle_pause',
        label: _isPaused ? 'Resume reminders' : 'Pause reminders',
      ),
      MenuItem(key: 'take_break', label: 'Take break now'),
      MenuItem(key: 'skip_next', label: 'Skip next break'),
      MenuItem.separator(),
      MenuItem(key: 'settings', label: 'Settings...'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: 'Quit'),
    ]);
    await trayManager.setContextMenu(menu);
  }

  void updatePauseState(bool isPaused) {
    _isPaused = isPaused;
    _buildMenu();
  }

  Future<void> setTrayTitle(String title) async {
    await trayManager.setTitle(title);
  }

  @override
  void onTrayIconMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final key = menuItem.key;
    if (key != null) {
      onMenuAction?.call(key);
    }
  }

  void dispose() {
    trayManager.removeListener(this);
  }
}
