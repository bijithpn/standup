import 'package:blobatar_flutter/blobatar_flutter.dart';

/// Pure mapping engine translating BreakMate companion & timer states
/// to deterministic Blobatar expressions.
class BlobatarEmotionMapper {
  /// Resolves the emotional expression for Blobatar according to the companion's current state.
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

  /// Sanitizes pet name, defaulting to "Blobby" if empty or whitespace.
  static String sanitizePetName(String? rawName) {
    if (rawName == null) return 'Blobby';
    final trimmed = rawName.trim();
    return trimmed.isEmpty ? 'Blobby' : trimmed;
  }
}
