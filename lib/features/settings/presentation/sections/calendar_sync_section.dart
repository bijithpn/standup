import 'package:breakmate/shared/widgets/minimal_controls.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/calendar/calendar_sync_controller.dart';
import 'package:breakmate/features/settings/presentation/sections/calendar_events_view.dart';
import 'package:breakmate/features/settings/widgets/settings_group.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// Settings > Calendar: connect/disconnect, meeting-quiet toggle and event previews; refreshes on app resume to pick up permission changes made in System Settings.
class CalendarSyncSection extends StatefulWidget {
  const CalendarSyncSection({super.key});

  @override
  State<CalendarSyncSection> createState() => _CalendarSyncSectionState();
}

class _CalendarSyncSectionState extends State<CalendarSyncSection>
    with WidgetsBindingObserver {
  late final CalendarSyncController _controller = sl<CalendarSyncController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _controller.refresh(force: true);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CalendarSyncController>.value(
      value: _controller,
      child: Consumer<CalendarSyncController>(
        builder: (context, c, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SettingsNote(
              'BreakMate reads event times to keep breaks out of meetings. Titles are shown here but never saved.',
            ),
            _StatusCard(controller: c),
            sectionHeader('Behavior'),
            buildCard([
              toggleRow(
                'Quiet reminders during meetings',
                c.state == CalendarConnectionState.connected
                    ? 'A subtle reminder instead of the full break screen during events'
                    : 'Connect your calendar to use this',
                c.quietDuringMeetings,
                (v) {
                  if (c.state == CalendarConnectionState.connected) {
                    c.setQuietDuringMeetings(v);
                  }
                },
              ),
            ]),
            if (c.state == CalendarConnectionState.connected) ...[
              TodayAgendaCard(controller: c),
              MonthCalendarCard(controller: c),
            ],
          ],
        ),
      ),
    );
  }
}

// Connection banner whose copy and action depend on [CalendarConnectionState].
class _StatusCard extends StatelessWidget {
  final CalendarSyncController controller;
  const _StatusCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final (String title, String body) = switch (c.state) {
      CalendarConnectionState.checking => (
        'Checking calendar access…',
        'One moment.',
      ),
      CalendarConnectionState.disconnected => (
        'Not connected',
        'Connect to keep breaks from interrupting your meetings.',
      ),
      CalendarConnectionState.connected => ('Connected', _syncedLabel(c)),
      CalendarConnectionState.permissionNeeded => (
        'Calendar access needed',
        'Allow calendar access when macOS asks, or in System Settings.',
      ),
      CalendarConnectionState.permissionBlocked => (
        'Calendar access blocked',
        'macOS is blocking access. In Privacy & Security → Calendars, '
            'turn BreakMate off and on again (or remove it with “−” and '
            'click Connect again), then come back.',
      ),
      CalendarConnectionState.error => (
        'Couldn’t read your calendar',
        'The last sync failed. Try again.',
      ),
    };

    final actions = <Widget>[
      switch (c.state) {
        CalendarConnectionState.disconnected ||
        CalendarConnectionState.permissionNeeded => MinimalButton(
          backgroundColor: AppTheme.accentColor,
          onPressed: c.isRequesting ? null : c.connect,
          child: c.isRequesting
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.onAccent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Requesting…'),
                  ],
                )
              : const Text('Connect'),
        ),
        CalendarConnectionState.permissionBlocked => MinimalButton(
          backgroundColor: AppTheme.accentColor,
          onPressed: c.openSystemSettings,
          child: const Text('Open system settings'),
        ),
        CalendarConnectionState.connected ||
        CalendarConnectionState.error => MinimalButton(
          isSecondary: true,
          onPressed: () => c.refresh(force: true),
          child: const Text('Sync now'),
        ),
        CalendarConnectionState.checking => MinimalButton(
          isSecondary: true,
          onPressed: null,
          child: const Text('Checking…'),
        ),
      },
      if (c.state == CalendarConnectionState.permissionBlocked ||
          c.state == CalendarConnectionState.permissionNeeded)
        MinimalButton(
          isGhost: true,
          onPressed: () => c.refresh(force: true),
          child: const Text('Recheck'),
        ),
      if (c.enabled && c.state != CalendarConnectionState.checking)
        MinimalButton(
          isGhost: true,
          onPressed: c.disconnect,
          child: Text(
            'Disconnect',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
    ];

    return SettingsGroup(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ),
        ),
      ],
    );
  }

  static String _syncedLabel(CalendarSyncController c) {
    final at = c.lastSyncedAt;
    if (at == null) return 'Waiting for the first sync…';
    final h = at.hour.toString().padLeft(2, '0');
    final m = at.minute.toString().padLeft(2, '0');
    return 'Last synced $h:$m';
  }
}
