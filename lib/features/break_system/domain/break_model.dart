enum BreakType { short, long }

class BreakModel {
  final BreakType type;
  final int durationSeconds;
  final String title;
  final String tip;
  final String? triggerReason;

  const BreakModel({
    required this.type,
    required this.durationSeconds,
    required this.title,
    required this.tip,
    this.triggerReason,
  });

  bool get isLong => type == BreakType.long;
}
