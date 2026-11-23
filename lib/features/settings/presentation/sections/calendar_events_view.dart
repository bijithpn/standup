import 'package:breakmate/shared/widgets/minimal_controls.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import 'package:breakmate/core/services/calendar_service.dart';
import 'package:breakmate/features/calendar/calendar_sync_controller.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _fullWeekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _hm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String _dayLabel(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1].substring(0, 3)}';

/// Today's events from [CalendarSyncController.events].
class TodayAgendaCard extends StatelessWidget {
  final CalendarSyncController controller;
  const TodayAgendaCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final events = [...?controller.events]
      ..sort((a, b) => a.start.compareTo(b.start));
    final loading = controller.isLoadingEvents && controller.events == null;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Today · ${_dayLabel(DateTime.now())}', style: _title),
              const Spacer(),
              if (events.isNotEmpty)
                Text(
                  '${events.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontFeatures: AppTheme.tabular,
                    color: AppTheme.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (loading)
            const _Empty(icon: CupertinoIcons.refresh, text: 'Loading events…')
          else if (events.isEmpty)
            const _Empty(
              icon: CupertinoIcons.checkmark_circle,
              text: 'Nothing scheduled today. Enjoy the free time.',
            )
          else
            for (final e in events) EventTile(event: e),
        ],
      ),
    );
  }
}

/// Month grid with per-day event list; loads each visible month on demand via [CalendarSyncController.eventsBetween].
class MonthCalendarCard extends StatefulWidget {
  final CalendarSyncController controller;
  const MonthCalendarCard({super.key, required this.controller});

  @override
  State<MonthCalendarCard> createState() => _MonthCalendarCardState();
}

class _MonthCalendarCardState extends State<MonthCalendarCard> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = DateTime.now();
  List<CalendarEvent> _events = const [];
  bool _loading = false;
  // Discards results of superseded loads when the user flips months quickly.
  int _token = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = ++_token;
    setState(() => _loading = true);
    List<CalendarEvent> result = const [];
    try {
      result = await widget.controller.eventsBetween(
        _month,
        DateTime(_month.year, _month.month + 1),
      );
    } catch (_) {}
    if (!mounted || token != _token) return;
    setState(() {
      _events = result;
      _loading = false;
    });
  }

  void _shift(int months) {
    setState(() {
      _month = DateTime(_month.year, _month.month + months);
      _selected = _sameMonth(DateTime.now(), _month) ? DateTime.now() : _month;
    });
    _load();
  }

  bool _sameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  List<CalendarEvent> _on(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(day.year, day.month, day.day + 1);
    return _events
        .where(
          (e) =>
              e.start.isBefore(end) && e.end.isAfter(start) ||
              _sameDay(e.start, day),
        )
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  @override
  Widget build(BuildContext context) {
    final first = _month;
    final lead = first.weekday - 1;
    final days = DateUtils.getDaysInMonth(first.year, first.month);
    final rows = ((lead + days) / 7).ceil();
    final selectedEvents = _on(_selected);

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${_months[_month.month - 1]} ${_month.year}',
                style: _title,
              ),
              if (_loading) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
              const Spacer(),
              _NavButton(
                icon: CupertinoIcons.chevron_left,
                label: 'Previous month',
                onTap: () => _shift(-1),
              ),
              const SizedBox(width: 4),
              MinimalButton(
                isGhost: true,
                onPressed: () {
                  final n = DateTime.now();
                  setState(() {
                    _month = DateTime(n.year, n.month);
                    _selected = n;
                  });
                  _load();
                },
                child: const Text('Today'),
              ),
              const SizedBox(width: 4),
              _NavButton(
                icon: CupertinoIcons.chevron_right,
                label: 'Next month',
                onTap: () => _shift(1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final d in _weekdays)
                Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (var r = 0; r < rows; r++)
            Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(child: _cell(r * 7 + c - lead + 1, days)),
              ],
            ),
          const SizedBox(height: 16),
          Divider(height: 1, color: AppTheme.borderSubtle),
          const SizedBox(height: 16),
          _SelectedDayHeader(day: _selected, eventCount: selectedEvents.length),
          const SizedBox(height: 8),
          if (selectedEvents.isEmpty)
            const _Empty(
              icon: CupertinoIcons.checkmark_circle,
              text: 'No events',
            )
          else
            for (final e in selectedEvents) EventTile(event: e),
        ],
      ),
    );
  }

  Widget _cell(int dayNum, int days) {
    if (dayNum < 1 || dayNum > days) return const SizedBox(height: 56);
    final day = DateTime(_month.year, _month.month, dayNum);
    final isToday = _sameDay(day, DateTime.now());
    final isSel = _sameDay(day, _selected);
    final count = _on(day).length;
    final textColor = isSel
        ? AppTheme.gray950
        : isToday
        ? AppTheme.accent
        : AppTheme.textPrimary;
    return Semantics(
      button: true,
      selected: isSel,
      label: _dayLabel(day),
      child: SizedBox(
        height: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Material(
              color: isSel ? AppTheme.accent : Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: isToday && !isSel
                    ? BorderSide(color: AppTheme.accent)
                    : BorderSide.none,
              ),
              child: InkWell(
                customBorder: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                hoverColor: AppTheme.hoverOverlay,
                onTap: () => setState(() => _selected = day),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: Text(
                      '$dayNum',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSel || isToday
                            ? FontWeight.w600
                            : FontWeight.w500,
                        fontFeatures: AppTheme.tabular,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < count.clamp(0, 3); i++)
                    Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: AppTheme.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedDayHeader extends StatelessWidget {
  final DateTime day;
  final int eventCount;
  const _SelectedDayHeader({required this.day, required this.eventCount});

  @override
  Widget build(BuildContext context) {
    final today = _sameDay(day, DateTime.now());
    final count = eventCount == 0
        ? 'No events'
        : '$eventCount ${eventCount == 1 ? 'event' : 'events'}';
    return Row(
      children: [
        Container(
          width: 52,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                _weekdays[day.weekday - 1].toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accent,
                ),
              ),
              Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  fontFeatures: AppTheme.tabular,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                today
                    ? 'Today'
                    : '${_fullWeekdays[day.weekday - 1]}, ${_months[day.month - 1]}',
                style: _title,
              ),
              const SizedBox(height: 2),
              Text(
                count,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Single event row (time range, title, all-day/ongoing state).
class EventTile extends StatelessWidget {
  final CalendarEvent event;
  const EventTile({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final live =
        !event.isAllDay && !event.start.isAfter(now) && event.end.isAfter(now);
    final past = !live && !event.isAllDay && event.end.isBefore(now);
    final platform = event.getMeetingPlatform();
    final accent = live ? AppTheme.success : AppTheme.accent;

    return Opacity(
      opacity: past ? 0.5 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.borderSubtle)),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              SizedBox(
                width: 56,
                child: event.isAllDay
                    ? Text(
                        'All day',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _hm(event.start),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              fontFeatures: AppTheme.tabular,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            _hm(event.end),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
              ),
              Container(
                width: 4,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (event.location.isNotEmpty || platform != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(
                              platform != null
                                  ? CupertinoIcons.videocam
                                  : CupertinoIcons.location,
                              size: 16,
                              color: AppTheme.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                platform ?? event.location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (live)
                Text(
                  'Now',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.success,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

TextStyle get _title => TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w500,
  color: AppTheme.textPrimary,
);

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppTheme.space24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        child,
        const SizedBox(height: AppTheme.space24),
        Divider(height: 1, color: AppTheme.borderSubtle),
      ],
    ),
  );
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _NavButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Semantics(
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        hoverColor: AppTheme.hoverOverlay,
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 16, color: AppTheme.textSecondary),
        ),
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Empty({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textMuted),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
      ],
    ),
  );
}
