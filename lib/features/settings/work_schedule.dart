/// One shift anchored to its start weekday. End before start means overnight.
class WorkSchedule {
  final String start;
  final String end;
  final String? lunchStart;
  final String? lunchEnd;

  const WorkSchedule({
    this.start = '09:00',
    this.end = '18:00',
    this.lunchStart,
    this.lunchEnd,
  });

  static int? minutes(String? value) {
    if (value == null || !RegExp(r'^\d{2}:\d{2}$').hasMatch(value)) return null;
    final parts = value.split(':').map(int.parse).toList();
    return parts[0] < 24 && parts[1] < 60 ? parts[0] * 60 + parts[1] : null;
  }

  bool get isValid {
    final s = minutes(start), e = minutes(end);
    if (s == null || e == null || s == e) return false;
    if (lunchStart == null && lunchEnd == null) return true;
    final ls = minutes(lunchStart), le = minutes(lunchEnd);
    if (ls == null || le == null) return false;
    final length = (e - s + 1440) % 1440;
    final offset = (ls - s + 1440) % 1440;
    final lunchLength = (le - ls + 1440) % 1440;
    return lunchLength > 0 && offset + lunchLength <= length;
  }

  bool contains(DateTime shiftDate, DateTime now) {
    if (!isValid) return false;
    final s = minutes(start)!, e = minutes(end)!;
    final begin = DateTime(
      shiftDate.year,
      shiftDate.month,
      shiftDate.day,
      s ~/ 60,
      s % 60,
    );
    final finish = DateTime(
      shiftDate.year,
      shiftDate.month,
      shiftDate.day + (e <= s ? 1 : 0),
      e ~/ 60,
      e % 60,
    );
    if (now.isBefore(begin) || !now.isBefore(finish)) return false;
    if (lunchStart != null) {
      final ls = minutes(lunchStart)!, le = minutes(lunchEnd)!;
      final lunchDay = shiftDate.day + (ls < s ? 1 : 0);
      final lunchBegin = DateTime(
        shiftDate.year,
        shiftDate.month,
        lunchDay,
        ls ~/ 60,
        ls % 60,
      );
      final lunchFinish = DateTime(
        shiftDate.year,
        shiftDate.month,
        lunchDay + (le <= ls ? 1 : 0),
        le ~/ 60,
        le % 60,
      );
      if (!now.isBefore(lunchBegin) && now.isBefore(lunchFinish)) return false;
    }
    return true;
  }

  DateTime? nextActiveTime(DateTime shiftDate, DateTime now) {
    if (!isValid) return null;
    if (contains(shiftDate, now)) return now;
    final s = minutes(start)!;
    final candidates = [
      DateTime(shiftDate.year, shiftDate.month, shiftDate.day, s ~/ 60, s % 60),
    ];
    if (lunchStart != null) {
      final ls = minutes(lunchStart)!, le = minutes(lunchEnd)!;
      candidates.add(
        DateTime(
          shiftDate.year,
          shiftDate.month,
          shiftDate.day + (ls < s ? 1 : 0) + (le <= ls ? 1 : 0),
          le ~/ 60,
          le % 60,
        ),
      );
    }
    for (final candidate in candidates) {
      if (!candidate.isBefore(now) && contains(shiftDate, candidate)) {
        return candidate;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'start': start,
    'end': end,
    'lunchStart': lunchStart,
    'lunchEnd': lunchEnd,
  };
  factory WorkSchedule.fromJson(Map<String, dynamic> json) => WorkSchedule(
    start: json['start'] as String? ?? '09:00',
    end: json['end'] as String? ?? '18:00',
    lunchStart: json['lunchStart'] as String?,
    lunchEnd: json['lunchEnd'] as String?,
  );

  static Map<int, WorkSchedule> decode(dynamic value) {
    if (value is! Map) return {};
    final result = <int, WorkSchedule>{};
    for (final entry in value.entries) {
      final day = int.tryParse(entry.key.toString());
      if (day == null || day < 1 || day > 7 || entry.value is! Map) continue;
      try {
        final shift = WorkSchedule.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
        if (shift.isValid) result[day] = shift;
      } catch (_) {
        /* Keep other valid days when importing malformed data. */
      }
    }
    return result;
  }
}
