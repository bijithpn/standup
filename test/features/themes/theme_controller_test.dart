import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/features/themes/themes.dart';

class InMemoryStorageService extends FakeStorageService {
  final Map<String, dynamic> _data = {};

  @override
  String getString(String key, {String defaultValue = ''}) {
    return _data[key] as String? ?? defaultValue;
  }

  @override
  Future<bool> setString(String key, String value) async {
    _data[key] = value;
    return true;
  }

  @override
  int getInt(String key, {int defaultValue = 0}) {
    return _data[key] as int? ?? defaultValue;
  }

  @override
  Future<bool> setInt(String key, int value) async {
    _data[key] = value;
    return true;
  }
}

class FakeStorageService implements StorageService {
  @override
  bool get isReady => true;
  @override
  bool get hasFailed => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('AppThemePreset Tests', () {
    test('contains all 12 curated presets', () {
      expect(AppThemePreset.allPresets.length, equals(12));
      final ids = AppThemePreset.allPresets.map((p) => p.id).toSet();
      expect(
        ids,
        containsAll([
          'nordic_slate',
          'solarized_amber',
          'tokyo_midnight',
          'forest_matcha',
          'e_ink_paper',
          'cyberpunk',
          'crimson_ember',
          'ocean_abyss',
          'aurora_borealis',
          'desert_dusk',
          'lavender_mist',
          'monokai_pro',
        ]),
      );
    });

    test('findById returns default on null or unrecognized id', () {
      expect(AppThemePreset.findById(null), equals(AppThemePreset.nordicSlate));
      expect(
        AppThemePreset.findById('unknown_theme_123'),
        equals(AppThemePreset.nordicSlate),
      );
      expect(
        AppThemePreset.findById('tokyo_midnight'),
        equals(AppThemePreset.tokyoMidnight),
      );
    });

    test('toMaterialTheme and toMacosTheme produce valid themes', () {
      final preset = AppThemePreset.forestMatcha;
      final matTheme = preset.toMaterialTheme();
      final macTheme = preset.toMacosTheme();

      expect(matTheme.primaryColor, equals(preset.primary));
      expect(matTheme.colorScheme.primary, equals(preset.accent));
      expect(macTheme.primaryColor, equals(preset.accent));
    });
  });

  group('ThemeController Tests', () {
    late InMemoryStorageService storage;
    late ThemeController controller;

    setUp(() {
      storage = InMemoryStorageService();
      controller = ThemeController(storage: storage);
    });

    test('initializes with default nordic slate', () {
      expect(controller.currentPreset, equals(AppThemePreset.nordicSlate));
      expect(controller.activeAccent, equals(AppThemePreset.nordicSlate.accent));
      expect(controller.customAccent, isNull);
    });

    test('setPreset updates currentPreset and persists id', () async {
      bool notified = false;
      controller.addListener(() => notified = true);

      await controller.setPreset('solarized_amber');

      expect(notified, isTrue);
      expect(controller.currentPreset.id, equals('solarized_amber'));
      expect(
        storage.getString('app_theme_preset_id'),
        equals('solarized_amber'),
      );
    });

    test('setCustomAccent overrides activeAccent and persists', () async {
      const customColor = Color(0xFFFF5722);
      await controller.setCustomAccent(customColor);

      expect(controller.customAccent, equals(customColor));
      expect(controller.activeAccent, equals(customColor));

      final reloaded = ThemeController(storage: storage);
      expect(reloaded.customAccent, equals(customColor));
    });

    test('resetToDefault resets preset and removes custom accent', () async {
      await controller.setPreset('cyberpunk');
      await controller.setCustomAccent(const Color(0xFF00FF00));

      await controller.resetToDefault();

      expect(controller.currentPreset, equals(AppThemePreset.nordicSlate));
      expect(controller.customAccent, isNull);
      expect(controller.activeAccent, equals(AppThemePreset.nordicSlate.accent));
    });
  });
}
