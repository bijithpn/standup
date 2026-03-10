enum BreakType { short, long }

class BreakModel {
  final BreakType type;
  final int durationSeconds;
  final String title;
  final String tip;

  const BreakModel({
    required this.type,
    required this.durationSeconds,
    required this.title,
    required this.tip,
  });

  bool get isLong => type == BreakType.long;
}
