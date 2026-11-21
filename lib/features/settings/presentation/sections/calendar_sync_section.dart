import 'package:breakmate/shared/widgets/minimal_controls.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/calendar/calendar_sync_controller.dart';
import 'package:breakmate/features/settings/presentation/sections/calendar_events_view.dart';
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
            sectionHeader(
              'Calendar sync',
              subtitle:
                  'Lets BreakMate see when your meetings are so breaks stay '
                  'out of the way. Only event times are used; titles are '
                  'shown here but never saved.',
            ),
            const SizedBox(height: 4),
            _StatusCard(controller: c),
            const SizedBox(height: 24),
            sectionHeader('Behavior'),
            buildCard([
              toggleRow(
                'Quiet reminders during meetings',
                c.state == CalendarConnectionState.connected
                    ? 'Show a subtle reminder instead of the full break screen '
                          'while a calendar event is in progress.'
                    : 'Connect your calendar to use this.',
                c.quietDuringMeetings,
                (v) {
                  if (c.state == CalendarConnectionState.connected) {
                    c.setQuietDuringMeetings(v);
                  }
                },
              ),
            ]),
            if (c.state == CalendarConnectionState.connected) ...[
              sectionHeader('Today'),
              TodayAgendaCard(controller: c),
              sectionHeader('Calendar'),
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
    final (
      IconData icon,
      Color color,
      String title,
      String body,
    ) = switch (c.state) {
      CalendarConnectionState.checking => (
        CupertinoIcons.clock,
        AppTheme.accent,
        'Checking calendar access…',
        'One moment.',
      ),
      CalendarConnectionState.disconnected => (
        CupertinoIcons.link,
        AppTheme.textSecondary,
        'Not connected',
        'Connect to let BreakMate avoid interrupting your meetings.',
      ),
      CalendarConnectionState.connected => (
        CupertinoIcons.checkmark_circle,
        AppTheme.success,
        'Connected',
        _syncedLabel(c),
      ),
      CalendarConnectionState.permissionNeeded => (
        CupertinoIcons.lock,
        AppTheme.warning,
        'Calendar access needed',
        'Allow calendar access when macOS asks, or in System Settings.',
      ),
      CalendarConnectionState.permissionBlocked => (
        CupertinoIcons.lock,
        AppTheme.warning,
        'Calendar access blocked',
        'macOS is blocking access. In Privacy & Security → Calendars, '
            'turn BreakMate off and on again (or remove it with “−” and '
            'click Connect again), then come back.',
      ),
      CalendarConnectionState.error => (
        CupertinoIcons.exclamationmark_circle,
        AppTheme.error,
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ),
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
