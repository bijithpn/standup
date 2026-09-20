import 'package:flutter_test/flutter_test.dart';
import 'package:blobatar_flutter/blobatar_flutter.dart';
import 'package:breakmate/features/companion/domain/blobatar_emotion_mapper.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';

void main() {
  group('BlobatarEmotionMapper', () {
    test('returns loveExpression when pet is tapped/petted', () {
      final expr = BlobatarEmotionMapper.resolveExpression(
        isOnBreak: false,
        isBreakOverdue: false,
        isPettedOrTapped: true,
      );
      expect(expr, equals(loveExpression));
    });

    test('returns loveExpression when on break', () {
      final expr = BlobatarEmotionMapper.resolveExpression(
        isOnBreak: true,
        isBreakOverdue: false,
        isPettedOrTapped: false,
      );
      expect(expr, equals(loveExpression));
    });

    test('returns madExpression when break is overdue', () {
      final expr = BlobatarEmotionMapper.resolveExpression(
        isOnBreak: false,
        isBreakOverdue: true,
        isPettedOrTapped: false,
      );
      expect(expr, equals(madExpression));
    });

    test('returns happyExpression during regular focus/working time', () {
      final expr = BlobatarEmotionMapper.resolveExpression(
        isOnBreak: false,
        isBreakOverdue: false,
        isPettedOrTapped: false,
      );
      expect(expr, equals(happyExpression));
    });

    test('returns thinkingExpression when break reminder is active', () {
      final expr = BlobatarEmotionMapper.resolveExpression(
        isOnBreak: false,
        isBreakOverdue: false,
        isPettedOrTapped: false,
        isBreakReminder: true,
      );
      expect(expr, equals(thinkingExpression));
    });

    test('sanitizes empty or whitespace names to default "Blobby"', () {
      expect(BlobatarEmotionMapper.sanitizePetName(''), equals('Blobby'));
      expect(BlobatarEmotionMapper.sanitizePetName('   '), equals('Blobby'));
      expect(BlobatarEmotionMapper.sanitizePetName('Cosmo'), equals('Cosmo'));
    });
  });

  group('PetTheme Blobatar integration', () {
    test('PetTheme.blobatar creates a valid blobatar theme', () {
      final theme = PetTheme.blobatar();
      expect(theme.id, equals('blobatar'));
      expect(theme.name, contains('Blobatar'));
      expect(theme.type, equals(PetType.blobatar));
      expect(theme.isBlobatar, isTrue);
    });

    test('PetTheme.themes includes blobatar', () {
      final blobThemes = PetTheme.themes.where((t) => t.isBlobatar);
      expect(blobThemes, isNotEmpty);
      expect(blobThemes.first.id, equals('blobatar'));
    });
  });
}
