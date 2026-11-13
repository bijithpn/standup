import 'package:breakmate/features/wellness/domain/app_categorizer.dart';

// Only these categories count as focused work.
const Set<AppCategory> kFocusCategories = {
  AppCategory.coding,
  AppCategory.writing,
  AppCategory.design,
};

bool isFocusCategory(AppCategory category) =>
    kFocusCategories.contains(category);

const int kMinFocusSessionSeconds = 15 * 60;

/// A continuous stretch of focus-category activity.
class FocusSession {
  final AppCategory category;
  final DateTime start;
  final int durationSeconds;

  const FocusSession({
    required this.category,
    required this.start,
    required this.durationSeconds,
  });

  DateTime get end => start.add(Duration(seconds: durationSeconds));

  Map<String, dynamic> toJson() => {
    'category': category.name,
    'start': start.toIso8601String(),
    'durationSeconds': durationSeconds,
  };

  factory FocusSession.fromJson(Map<String, dynamic> json) {
    return FocusSession(
      category: AppCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => AppCategory.general,
      ),
      start: DateTime.tryParse(json['start'] as String? ?? '') ?? DateTime(0),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
    );
  }
}
