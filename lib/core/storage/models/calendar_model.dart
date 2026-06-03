class CalendarModel {
  final String id;
  final String name;
  final String color;
  final bool isReadOnly;

  CalendarModel({
    required this.id,
    required this.name,
    required this.color,
    required this.isReadOnly,
  });

  factory CalendarModel.fromJson(Map<String, dynamic> json) {
    return CalendarModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      color: json['color'] as String? ?? '',
      isReadOnly: json['isReadOnly'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'color': color, 'isReadOnly': isReadOnly};
  }
}
