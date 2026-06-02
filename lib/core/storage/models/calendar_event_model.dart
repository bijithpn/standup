class CalendarEventModel {
  final String id;
  final String calendarId;
  final String title;
  final String notes;
  final String location;
  final String url;
  final DateTime start;
  final DateTime end;
  final bool allDay;

  CalendarEventModel({
    required this.id,
    required this.calendarId,
    required this.title,
    required this.notes,
    required this.location,
    required this.url,
    required this.start,
    required this.end,
    required this.allDay,
  });

  factory CalendarEventModel.fromJson(Map<String, dynamic> json) {
    return CalendarEventModel(
      id: json['id'] as String? ?? '',
      calendarId: json['calendarId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      location: json['location'] as String? ?? '',
      url: json['url'] as String? ?? '',
      start: DateTime.fromMillisecondsSinceEpoch(json['start'] as int? ?? 0),
      end: DateTime.fromMillisecondsSinceEpoch(json['end'] as int? ?? 0),
      allDay: json['allDay'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'calendarId': calendarId,
      'title': title,
      'notes': notes,
      'location': location,
      'url': url,
      'start': start.millisecondsSinceEpoch,
      'end': end.millisecondsSinceEpoch,
      'allDay': allDay,
    };
  }
}
