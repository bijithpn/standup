import 'settings_group.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/native/native_bridge.dart';
import 'package:breakmate/core/services/app_navigation_service.dart';
import 'package:breakmate/core/services/notification_service.dart';
import 'package:breakmate/features/settings/widgets/status_pill.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  String? _message;
  Timer? _messageTimer;

  // No Scaffold exists on this page, so feedback is shown inline instead of a SnackBar.
  void _toast(String message) {
    if (!mounted) return;
    setState(() => _message = message);
    _messageTimer?.cancel();
    _messageTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _message = null);
    });
  }

  Future<void> _refresh({bool announce = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
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
      if (announce) _toast('Permissions checked');
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('Could not check permissions. Try again.');
    }
  }

  Future<void> _requestNotifications() async {
    if (!sl.isRegistered<NotificationService>()) return;
    final granted = await sl<NotificationService>()
        .requestNotificationPermission();
    await _refresh();
    _toast(
      granted
          ? 'Notifications allowed'
          : 'Notifications are still blocked. Open system settings to allow them.',
    );
  }

  Future<void> _open(String url, String fallback) async {
    var opened = false;
    try {
      opened = await launchUrl(Uri.parse(url));
    } catch (_) {}
    _toast(opened ? 'Opened system settings' : fallback);
  }

  Widget _row(
    String title,
    String status,
    StatusPill pill,
    List<Widget> actions,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            pill,
          ],
        ),
        const SizedBox(height: 6),
        Text(
          status,
          style: TextStyle(
            fontSize: 12,
            height: 1.5,
            color: AppTheme.textSecondary,
          ),
        ),
        if (actions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(spacing: 8, runSpacing: 8, children: actions),
          ),
      ],
    ),
  );

  Widget _button(String label, VoidCallback? onPressed) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      foregroundColor: AppTheme.accentColor,
      side: BorderSide(color: AppTheme.accentColor.withValues(alpha: 0.5)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
  );

  void _goTo(String section) {
    if (sl.isRegistered<AppNavigationService>()) {
      sl<AppNavigationService>().openSection(section);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final calendarOk =
        _calendar.toLowerCase().contains('granted') ||
        _calendar.toLowerCase().contains('authorized');
    return SettingsGroup(
      children: [
        _row(
          'Notifications',
          !s.notificationsEnabled
              ? 'Turned off in BreakMate. Turn them on in Notifications settings.'
              : _notifications == false
              ? 'Blocked by the system, so break reminders cannot appear.'
              : _notifications == true
              ? 'Break reminders can appear.'
              : 'The system does not report this on your platform.',
          !s.notificationsEnabled
              ? const StatusPill('Off', tone: PillTone.off)
              : _notifications == true
              ? const StatusPill('Allowed', tone: PillTone.ok)
              : _notifications == false
              ? const StatusPill('Blocked', tone: PillTone.warn)
              : const StatusPill('Unknown', tone: PillTone.off),
          [
            if (Platform.isMacOS && _notifications != true)
              _button('Allow notifications', _requestNotifications),
            _button('Notification settings', () => _goTo('Notifications')),
            if (Platform.isMacOS || Platform.isWindows)
              _button(
                'System settings',
                () => _open(
                  Platform.isMacOS
                      ? 'x-apple.systempreferences:com.apple.preference.notifications'
                      : 'ms-settings:notifications',
                  'Could not open system settings. Allow notifications for BreakMate there.',
                ),
              ),
          ],
        ),
        _row(
          'Calendar',
          !s.calendarEnabled
              ? 'Not connected. Connect a calendar to keep breaks quiet during events.'
              : 'Access status: $_calendar',
          !s.calendarEnabled
              ? const StatusPill('Off', tone: PillTone.off)
              : calendarOk
              ? const StatusPill('Allowed', tone: PillTone.ok)
              : const StatusPill('Needs attention', tone: PillTone.warn),
          [_button('Manage calendar access', () => _goTo('Calendar Sync'))],
        ),
        if (Platform.isMacOS)
          _row(
            'Accessibility',
            'BreakMate cannot read this status. If call detection misses an app, check that access is allowed.',
            const StatusPill('Not reported', tone: PillTone.off),
            [
              _button(
                'Open Accessibility settings',
                () => _open(
                  'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility',
                  'Could not open settings. Go to System Settings, Privacy & Security, Accessibility.',
                ),
              ),
            ],
          ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Semantics(
              liveRegion: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppTheme.accentColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _message!,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _loading ? null : () => _refresh(announce: true),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(_loading ? 'Checking' : 'Check again'),
            ),
          ),
        ),
      ],
    );
  }
}
