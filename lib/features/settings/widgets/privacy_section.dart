import 'package:breakmate/features/analytics/focus_session_service.dart';
import 'package:breakmate/core/config/productivity_config.dart';
import 'package:breakmate/features/analytics/presentation/productivity/activity_tracking_intro.dart';
import 'package:breakmate/features/analytics/segments/activity_segment_repository.dart';
import 'package:breakmate/features/analytics/segments/productivity_repository.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/analytics/app_usage_service.dart';
import 'package:breakmate/core/services/app_navigation_service.dart';
import 'package:breakmate/core/services/calendar_permission_service.dart';
import 'package:breakmate/features/calendar/calendar_sync_controller.dart';
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/core/services/simple_prefs.dart';
import 'package:breakmate/features/settings/local_data_wiper.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

class PrivacySection extends StatefulWidget {
  final SettingsModel settings;
  final ValueChanged<SettingsModel> onSave;

  const PrivacySection({
    super.key,
    required this.settings,
    required this.onSave,
  });

  @override
  State<PrivacySection> createState() => _PrivacySectionState();
}

class _PrivacySectionState extends State<PrivacySection> {
  /// How many activity entries are stored, so "clear history" can say what it
  /// would actually delete.
  int _segmentCount = 0;

  bool _crashReporting = SimplePrefs.instance.getBool(
    AppConstants.keyCrashReportingEnabled,
    defaultValue: true,
  );

  @override
  void initState() {
    super.initState();
    _refreshSegmentCount();
    // Shared, throttled: shows the real calendar permission state.
    sl<CalendarSyncController>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;

    final calendar = sl<CalendarSyncController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader(
          'Privacy',
          subtitle:
              'Everything BreakMate records is stored on this Mac. There are '
              'no accounts and no servers, and nothing is sent anywhere.',
        ),

        // ── Permissions ─────────────────────────────────────────────────
        sectionHeader('Permissions'),
        ChangeNotifierProvider<CalendarSyncController>.value(
          value: calendar,
          child: Consumer<CalendarSyncController>(
            builder: (context, c, _) => buildCard([
              _PermissionRow(
                title: 'Calendar',
                detail:
                    'Reads event times to keep breaks out of meetings. '
                    'Titles are never saved.',
                status: _calendarStatus(c),
                actionLabel:
                    c.state == CalendarConnectionState.permissionBlocked
                    ? 'Open System Settings'
                    : 'Manage in Calendar Sync',
                onAction: c.state == CalendarConnectionState.permissionBlocked
                    ? c.openSystemSettings
                    : () => sl<AppNavigationService>().openSection(
                        'Calendar Sync',
                      ),
              ),
            ]),
          ),
        ),

        // ── Data collection ─────────────────────────────────────────────
        sectionHeader('Data collection'),
        buildCard([
          toggleRow(
            'Track app usage',
            'Stores app names and time spent, locally. Never window titles, '
                'URLs or documents.',
            settings.appUsageTrackingEnabled,
            (value) => _setTracking(settings, value),
          ),
          if (settings.appUsageTrackingEnabled) ...[
            divider(),
            dropdownRow(
              'Keep activity history',
              ActivityRetention.fromDays(
                settings.activityHistoryRetentionDays,
              ).label,
              ActivityRetention.values.map((r) => r.label).toList(),
              (value) {
                if (value == null) return;
                widget.onSave(
                  settings.copyWith(
                    activityHistoryRetentionDays: ActivityRetention.fromLabel(
                      value,
                    ).days,
                  ),
                );
              },
            ),
            divider(),
            actionRow(
              label: 'Clear activity history',
              subtitle: _segmentCount == 0
                  ? 'Nothing recorded yet.'
                  : '$_segmentCount recorded entries.',
              buttonText: 'Clear',
              onPressed: _segmentCount == 0 ? null : _clearActivityHistory,
              isDestructive: true,
            ),
          ],
          divider(),
          toggleRow(
            'Send crash reports',
            'Anonymised error reports (no app usage, titles, URLs or paths) '
                'so bugs can be fixed.',
            _crashReporting,
            (value) {
              SimplePrefs.instance.setBool(
                AppConstants.keyCrashReportingEnabled,
                value,
              );
              setState(() => _crashReporting = value);
            },
          ),
        ]),
        _DataTransparencyPanel(enabled: settings.appUsageTrackingEnabled),

        // ── Recorded data ───────────────────────────────────────────────
        // The detailed app-usage view lives on the Statistics screen only.
        if (settings.appUsageTrackingEnabled) ...[
          sectionHeader('Recorded app usage'),
          buildCard([
            actionRow(
              label: 'See exactly what was recorded',
              subtitle:
                  'Every tracked app and the time spent, by day, week or month.',
              buttonText: 'Open Statistics',
              onPressed: () =>
                  sl<AppNavigationService>().openSection('Statistics'),
            ),
          ]),
        ],

        // ── Your data ───────────────────────────────────────────────────
        const SizedBox(height: 24),
        sectionHeader('Your data'),
        buildCard([
          actionRow(
            label: 'Delete all local data',
            subtitle:
                'Resets all settings and permanently deletes statistics and '
                'activity history. Exported backups are not affected.',
            buttonText: 'Delete…',
            onPressed: _confirmWipeAllData,
            isDestructive: true,
          ),
        ]),
      ],
    );
  }

  _PermissionStatus _calendarStatus(CalendarSyncController c) {
    switch (c.state) {
      case CalendarConnectionState.connected:
        return _PermissionStatus.granted;
      case CalendarConnectionState.permissionBlocked:
        return _PermissionStatus.denied;
      case CalendarConnectionState.permissionNeeded:
        return _PermissionStatus.notRequested;
      case CalendarConnectionState.error:
        return _PermissionStatus.granted;
      case CalendarConnectionState.checking:
        return _PermissionStatus.checking;
      case CalendarConnectionState.disconnected:
        return c.permission == CalendarPermissionStatus.granted
            ? _PermissionStatus.granted
            : c.permission == CalendarPermissionStatus.notDetermined
            ? _PermissionStatus.notRequested
            : _PermissionStatus.denied;
    }
  }

  /// Turning tracking on for the first time explains itself before it starts;
  /// turning it off is immediate, because stopping never needs consent.
  Future<void> _setTracking(SettingsModel settings, bool value) async {
    if (!value) {
      widget.onSave(settings.copyWith(appUsageTrackingEnabled: false));
      return;
    }

    final accepted = await ActivityTrackingIntro.show(context);
    if (!accepted) return;

    widget.onSave(settings.copyWith(appUsageTrackingEnabled: true));
    _refreshSegmentCount();
  }

  Future<void> _clearActivityHistory() async {
    if (!sl.isRegistered<ActivitySegmentRepository>()) return;

    final confirmed = await ClearActivityHistoryDialog.show(
      context,
      segmentCount: _segmentCount,
    );
    if (!confirmed) return;

    sl<ActivitySegmentRepository>().clearAll();
    if (sl.isRegistered<AppUsageService>()) sl<AppUsageService>().clear();
    if (sl.isRegistered<FocusSessionService>()) {
      sl<FocusSessionService>().clear();
    }
    if (sl.isRegistered<ProductivityRepository>()) {
      sl<ProductivityRepository>().invalidate();
    }
    _refreshSegmentCount();
  }

  Future<void> _confirmWipeAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all local data?'),
        content: const Text(
          'This resets all settings and permanently deletes your statistics '
          'and activity history. Backups you exported are not affected. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await wipeAllLocalData();
    _refreshSegmentCount();
  }

  void _refreshSegmentCount() {
    if (!mounted) return;
    setState(() {
      _segmentCount = sl.isRegistered<ActivitySegmentRepository>()
          ? sl<ActivitySegmentRepository>().count()
          : 0;
    });
  }
}

/// Plain-language breakdown of exactly what the app usage feature stores,
/// how long it's kept, and what it never touches — the "what we know"
/// half of the dashboard, next to the "here's the data" half above.
class _DataTransparencyPanel extends StatelessWidget {
  final bool enabled;

  const _DataTransparencyPanel({required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.shieldCheck, size: 16, color: AppTheme.success),
              const SizedBox(width: 8),
              Text(
                'What exactly is stored',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _TransparencyRow(
            icon: LucideIcons.checkCircle2,
            iconColor: AppTheme.success,
            text: 'App name and category (e.g. "Xcode" — Development)',
          ),
          _TransparencyRow(
            icon: LucideIcons.checkCircle2,
            iconColor: AppTheme.success,
            text: 'Seconds spent per app, per day',
          ),
          _TransparencyRow(
            icon: LucideIcons.xCircle,
            iconColor: AppTheme.error,
            text: 'Window titles — never recorded',
          ),
          _TransparencyRow(
            icon: LucideIcons.xCircle,
            iconColor: AppTheme.error,
            text: 'URLs, documents, or file names — never recorded',
          ),
          _TransparencyRow(
            icon: LucideIcons.xCircle,
            iconColor: AppTheme.error,
            text: 'Activity data is never sent off this device',
          ),
          _TransparencyRow(
            icon: LucideIcons.info,
            iconColor: AppTheme.info,
            text:
                'The window title and browser tab address are read only for a '
                'moment to recognise meetings, then discarded',
          ),
          _TransparencyRow(
            icon: LucideIcons.info,
            iconColor: AppTheme.info,
            text:
                'Exported backups include your activity history — keep them private',
          ),
          const SizedBox(height: 8),
          Text(
            enabled
                ? 'History rolls off automatically after 30 days.'
                : 'Tracking is off. Existing history still ages out after 30 days.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _TransparencyRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;

  const _TransparencyRow({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

enum _PermissionStatus { checking, granted, notRequested, denied }

class _PermissionRow extends StatelessWidget {
  final String title;
  final String detail;
  final _PermissionStatus status;
  final String actionLabel;
  final VoidCallback onAction;

  const _PermissionRow({
    required this.title,
    required this.detail,
    required this.status,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final (String label, Color color) = switch (status) {
      _PermissionStatus.checking => ('Checking…', AppTheme.textSecondary),
      _PermissionStatus.granted => ('Granted', AppTheme.success),
      _PermissionStatus.notRequested => ('Not requested', AppTheme.warning),
      _PermissionStatus.denied => ('Denied', AppTheme.error),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
