import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/calendar/calendar_sync_controller.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// The one place to connect a calendar and configure how BreakMate uses it.
/// Everything else (Today, Smart detection) links here instead of repeating it.
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
    // Throttled and de-duplicated by the controller.
    _controller.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from System Settings: pick up a permission change.
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
              'Calendar Sync',
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
              _EventsCard(controller: c),
            ],
          ],
        ),
      ),
    );
  }
}

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
        Icons.hourglass_top_rounded,
        AppTheme.accent,
        'Checking calendar access…',
        'One moment.',
      ),
      CalendarConnectionState.disconnected => (
        Icons.link_off_rounded,
        AppTheme.textSecondary,
        'Not connected',
        'Connect to let BreakMate avoid interrupting your meetings.',
      ),
      CalendarConnectionState.connected => (
        Icons.check_circle_outline_rounded,
        AppTheme.success,
        'Connected',
        _syncedLabel(c),
      ),
      CalendarConnectionState.permissionNeeded => (
        Icons.lock_outline_rounded,
        AppTheme.warning,
        'Calendar access needed',
        'Allow calendar access when macOS asks, or in System Settings.',
      ),
      CalendarConnectionState.permissionBlocked => (
        Icons.lock_outline_rounded,
        AppTheme.warning,
        'Calendar access blocked',
        'macOS is blocking access. Enable BreakMate under Privacy & '
            'Security → Calendars, then come back.',
      ),
      CalendarConnectionState.error => (
        Icons.error_outline_rounded,
        AppTheme.error,
        'Couldn’t read your calendar',
        'The last sync failed. Try again.',
      ),
    };

    final actions = <Widget>[
      switch (c.state) {
        CalendarConnectionState.disconnected ||
        CalendarConnectionState.permissionNeeded => FilledButton(
          onPressed: c.isRequesting ? null : c.connect,
          child: Text(c.isRequesting ? 'Requesting…' : 'Connect'),
        ),
        CalendarConnectionState.permissionBlocked => FilledButton(
          onPressed: c.openSystemSettings,
          child: const Text('Open System Settings'),
        ),
        CalendarConnectionState.connected ||
        CalendarConnectionState.error => OutlinedButton(
          onPressed: () => c.refresh(force: true),
          child: const Text('Sync now'),
        ),
        CalendarConnectionState.checking => const SizedBox.shrink(),
      },
      if (c.state == CalendarConnectionState.permissionBlocked ||
          c.state == CalendarConnectionState.permissionNeeded)
        TextButton(
          onPressed: () => c.refresh(force: true),
          child: const Text('Recheck'),
        ),
      if (c.enabled && c.state != CalendarConnectionState.checking)
        TextButton(
          onPressed: c.disconnect,
          child: Text(
            'Disconnect',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
                        fontWeight: FontWeight.w600,
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
          const SizedBox(height: 14),
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

class _EventsCard extends StatelessWidget {
  final CalendarSyncController controller;
  const _EventsCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final events = controller.events;
    final String text;
    if (controller.isLoadingEvents && events == null) {
      text = 'Loading…';
    } else if (events == null || events.isEmpty) {
      text = 'No events today.';
    } else {
      final timed = events.where((e) => !e.isAllDay).length;
      text =
          '${events.length} event${events.length == 1 ? '' : 's'} today'
          '${timed == events.length ? '' : ' ($timed with a set time)'}.';
    }
    return buildCard([
      Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          text,
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
      ),
    ]);
  }
}
