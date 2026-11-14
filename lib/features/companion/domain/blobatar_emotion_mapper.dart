import 'package:blobatar_flutter/blobatar_flutter.dart';

/// Chooses the Blobatar expression from break/interaction state (priority: pet > on break > overdue > reminder > default).
class BlobatarEmotionMapper {
  static Expression resolveExpression({
    required bool isOnBreak,
    required bool isBreakOverdue,
    required bool isPettedOrTapped,
    bool isBreakReminder = false,
  }) {
    if (isPettedOrTapped) {
      return loveExpression;
    }
    if (isOnBreak) {
      return loveExpression;
    }
    if (isBreakOverdue) {
      return madExpression;
    }
    if (isBreakReminder) {
      return thinkingExpression;
    }
    return happyExpression;
  }

  static String sanitizePetName(String? rawName) {
    if (rawName == null) return 'Blobby';
    final trimmed = rawName.trim();
    return trimmed.isEmpty ? 'Blobby' : trimmed;
  }
}
