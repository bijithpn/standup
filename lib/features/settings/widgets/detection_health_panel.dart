import 'settings_group.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/native/native_bridge.dart';
import 'package:breakmate/core/services/app_navigation_service.dart';
import 'package:breakmate/core/services/notification_service.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import '../settings_model.dart';

/// Permission reads never prompt. Requests and system settings require a click.
class DetectionHealthPanel extends StatefulWidget {
  final SettingsModel settings;
  const DetectionHealthPanel({super.key, required this.settings});
  @override
  State<DetectionHealthPanel> createState() => _DetectionHealthPanelState();
}

class _DetectionHealthPanelState extends State<DetectionHealthPanel>
    with WidgetsBindingObserver {
  bool _loading = false;
  bool? _notifications;
  String _calendar = 'Not checked';
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final notificationStatus = sl.isRegistered<NotificationService>()
          ? await sl<NotificationService>().permissionAllowed()
          : null;
      final calendarStatus = !widget.settings.calendarEnabled
          ? 'Disabled'
          : Platform.isMacOS
          ? await NativeBridge.getCalendarPermissionStatus()
          : 'Unavailable on this platform';
      if (!mounted) return;
      setState(() {
        _notifications = notificationStatus;
        _calendar = calendarStatus;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not check permissions. Try refreshing.';
        });
      }
    }
  }

  Future<void> _requestNotifications() async {
    if (!sl.isRegistered<NotificationService>()) return;
    await sl<NotificationService>().requestNotificationPermission();
    if (mounted) await _refresh();
  }

  Future<void> _openNotificationSettings() async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(
          Platform.isMacOS
              ? 'x-apple.systempreferences:com.apple.preference.notifications'
              : 'ms-settings:notifications',
        ),
      );
    } catch (_) {}
    if (!opened && mounted) {
      setState(
        () => _error =
            'Open your system notification settings and allow notifications for BreakMate.',
      );
    }
  }

  Future<void> _openSystemSettings() async {
    bool opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(
          'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility',
        ),
      );
    } catch (_) {}
    if (!opened && mounted) {
      setState(
        () => _error =
            'Open System Settings → Privacy & Security → Accessibility.',
      );
    }
  }

  Widget _buildPanel(BuildContext context) {
    final engine = sl.isRegistered<TimerEngine>() ? sl<TimerEngine>() : null;
    final content = SettingsGroup(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Permissions & detection health',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: _loading ? null : _refresh,
              child: Text(_loading ? 'Checking…' : 'Refresh'),
            ),
          ],
        ),
        _row(
          'System notifications',
          !widget.settings.notificationsEnabled
              ? 'Disabled in BreakMate. Enable in Notifications settings.'
              : _notifications == true
              ? 'Allowed by the system'
              : _notifications == false
              ? 'Blocked by the system. Allow notifications for BreakMate.'
              : 'System permission status is unavailable on this platform.',
          action: Wrap(
            spacing: 8,
            children: [
              if (Platform.isMacOS)
                TextButton(
                  onPressed: _requestNotifications,
                  child: const Text('Request access'),
                ),
              TextButton(
                onPressed: () {
                  if (sl.isRegistered<AppNavigationService>()) {
                    sl<AppNavigationService>().openSection('Notifications');
                  }
                },
                child: const Text('Configure notifications'),
              ),
              if (Platform.isMacOS || Platform.isWindows)
                TextButton(
                  onPressed: _openNotificationSettings,
                  child: const Text('System settings'),
                ),
            ],
          ),
        ),
        _row(
          'Calendar',
          !widget.settings.calendarEnabled
              ? 'Disabled. Connect a calendar to plan around events.'
              : _calendar,
          action: TextButton(
            onPressed: () {
              if (sl.isRegistered<AppNavigationService>()) {
                sl<AppNavigationService>().openSection('Calendar Sync');
              }
            },
            child: const Text('Set up calendar'),
          ),
        ),
        _row(
          'Calls & meetings',
          !widget.settings.detectVideoCalls && !widget.settings.detectMeetings
              ? 'Disabled in BreakMate'
              : engine == null
              ? 'Status unavailable'
              : engine.contextManager.isMeetingActive()
              ? 'Meeting detected — breaks use quiet reminders'
              : 'No meeting detected. Automatic detection can miss some calls.',
        ),
        _row(
          'Presentation pause',
          !widget.settings.presentationPauseEnabled
              ? 'Disabled in BreakMate'
              : engine == null
              ? 'Status unavailable'
              : engine.contextManager.isSmartPauseActive()
              ? 'Smart pause active — check the timer for its current reason'
              : 'No smart pause active',
        ),
        if (Platform.isMacOS)
          _row(
            'Accessibility access',
            'Permission status is not reported by the detector. If call detection misses apps, review access in System Settings.',
            action: TextButton(
              onPressed: _openSystemSettings,
              child: const Text('Review access'),
            ),
          ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
    return content;
  }

  @override
  Widget build(BuildContext context) {
    final engine = sl.isRegistered<TimerEngine>() ? sl<TimerEngine>() : null;
    return engine == null
        ? _buildPanel(context)
        : ListenableBuilder(
            listenable: engine,
            builder: (context, _) => _buildPanel(context),
          );
  }

  Widget _row(String title, String status, {Widget? action}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          status,
          style: TextStyle(
            fontSize: 12,
            height: 1.6,
            color: AppTheme.textSecondary,
          ),
        ),
        if (action != null)
          Padding(padding: const EdgeInsets.only(top: 8), child: action),
      ],
    ),
  );
}
