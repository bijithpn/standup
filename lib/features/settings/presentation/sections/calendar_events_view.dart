import 'package:flutter/material.dart';

import 'package:breakmate/core/services/calendar_service.dart';
import 'package:breakmate/features/calendar/calendar_sync_controller.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
  'September', 'October', 'November', 'December', //
];

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _hm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String _dayLabel(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1].substring(0, 3)}';

/// Today's agenda: a timeline of the day's events with the current one marked.
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
              Icon(Icons.today_rounded, size: 18, color: AppTheme.accent),
              const SizedBox(width: 8),
              Text('Today · ${_dayLabel(DateTime.now())}', style: _title),
              const Spacer(),
              if (events.isNotEmpty) _Pill('${events.length}'),
            ],
          ),
          const SizedBox(height: 14),
          if (loading)
            const _Empty(icon: Icons.sync_rounded, text: 'Loading events…')
          else if (events.isEmpty)
            const _Empty(
              icon: Icons.free_breakfast_outlined,
              text: 'Nothing scheduled today. Enjoy the free time.',
            )
          else
            for (final e in events) EventTile(event: e),
        ],
      ),
    );
  }
}

/// Full month view with an event dot per day and the selected day's agenda.
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
              Icon(
                Icons.calendar_month_rounded,
                size: 18,
                color: AppTheme.accent,
              ),
              const SizedBox(width: 8),
              Text(
                '${_months[_month.month - 1]} ${_month.year}',
                style: _title,
              ),
              if (_loading) ...[
                const SizedBox(width: 10),
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
              const Spacer(),
              _NavButton(
                icon: Icons.chevron_left_rounded,
                onTap: () => _shift(-1),
              ),
              const SizedBox(width: 4),
              TextButton(
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
                icon: Icons.chevron_right_rounded,
                onTap: () => _shift(1),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final d in _weekdays)
                Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var r = 0; r < rows; r++)
            Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(child: _cell(r * 7 + c - lead + 1, days)),
              ],
            ),
          const SizedBox(height: 16),
          Divider(height: 1, color: AppTheme.borderSubtle),
          const SizedBox(height: 14),
          Text(
            _sameDay(_selected, DateTime.now())
                ? 'Today'
                : _dayLabel(_selected),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          if (selectedEvents.isEmpty)
            const _Empty(
              icon: Icons.event_available_outlined,
              text: 'No events',
            )
          else
            for (final e in selectedEvents) EventTile(event: e),
        ],
      ),
    );
  }

  Widget _cell(int dayNum, int days) {
    if (dayNum < 1 || dayNum > days) return const SizedBox(height: 46);
    final day = DateTime(_month.year, _month.month, dayNum);
    final isToday = _sameDay(day, DateTime.now());
    final isSel = _sameDay(day, _selected);
    final count = _on(day).length;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selected = day),
      child: Container(
        height: 46,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSel
              ? AppTheme.accent.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: isToday ? AppTheme.accent : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$dayNum',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isToday || isSel
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: isSel ? AppTheme.accent : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: 5,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < count.clamp(0, 3); i++)
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
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

/// One event row: time column, accent bar, title and details.
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
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: live ? 0.10 : 0.06),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              SizedBox(
                width: 50,
                child: event.isAllDay
                    ? Text(
                        'All day',
                        style: TextStyle(
                          fontSize: 11,
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
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            _hm(event.end),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
              ),
              Container(
                width: 3,
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
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (event.location.isNotEmpty || platform != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(
                          children: [
                            Icon(
                              platform != null
                                  ? Icons.videocam_outlined
                                  : Icons.place_outlined,
                              size: 12,
                              color: AppTheme.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                platform ?? event.location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
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
              if (live) const _Pill('Now', color: AppTheme.success),
            ],
          ),
        ),
      ),
    );
  }
}

TextStyle get _title => TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w600,
  color: AppTheme.textPrimary,
);

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 24),
    padding: const EdgeInsets.all(18),
    decoration: AppTheme.cardDecoration(),
    child: child,
  );
}

class _Pill extends StatelessWidget {
  final String text;
  final Color? color;
  const _Pill(this.text, {this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(8),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: Icon(icon, size: 20, color: AppTheme.textSecondary),
    ),
  );
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Empty({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.textMuted),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
      ],
    ),
  );
}
