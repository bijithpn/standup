import 'package:standup/core/constants/app_constants.dart';
import 'package:standup/core/services/storage_service.dart';
import 'package:standup/features/settings/settings_model.dart';

class SettingsRepository {
  final StorageService _storage;
  SettingsModel _current = const SettingsModel();

  SettingsRepository({required StorageService storage}) : _storage = storage;

  SettingsModel get currentSettings => _current;

  void load() {
    _current = SettingsModel(
      shortBreakIntervalMinutes: _storage.getInt(
        AppConstants.keyShortBreakInterval,
        defaultValue: AppConstants.defaultShortBreakIntervalMinutes,
      ),
      shortBreakDurationSeconds: _storage.getInt(
        AppConstants.keyShortBreakDuration,
        defaultValue: AppConstants.defaultShortBreakDurationSeconds,
      ),
      longBreakIntervalMinutes: _storage.getInt(
        AppConstants.keyLongBreakInterval,
        defaultValue: AppConstants.defaultLongBreakIntervalMinutes,
      ),
      longBreakDurationMinutes: _storage.getInt(
        AppConstants.keyLongBreakDuration,
        defaultValue: AppConstants.defaultLongBreakDurationMinutes,
      ),
      soundEnabled: _storage.getBool(
        AppConstants.keySoundEnabled,
        defaultValue: true,
      ),
      autoStart: _storage.getBool(AppConstants.keyAutoStart),
      strictMode: _storage.getBool(AppConstants.keyStrictMode),
      selectedProfileId: _storage.getString('selected_profile_id', defaultValue: 'health'),
      menuBarStyle: _storage.getString('menu_bar_style', defaultValue: 'countdown'),
    );
  }

  Future<void> save(SettingsModel settings) async {
    _current = settings;
    await Future.wait([
      _storage.setInt(
        AppConstants.keyShortBreakInterval,
        settings.shortBreakIntervalMinutes,
      ),
      _storage.setInt(
        AppConstants.keyShortBreakDuration,
        settings.shortBreakDurationSeconds,
      ),
      _storage.setInt(
        AppConstants.keyLongBreakInterval,
        settings.longBreakIntervalMinutes,
      ),
      _storage.setInt(
        AppConstants.keyLongBreakDuration,
        settings.longBreakDurationMinutes,
      ),
      _storage.setBool(AppConstants.keySoundEnabled, settings.soundEnabled),
      _storage.setBool(AppConstants.keyAutoStart, settings.autoStart),
      _storage.setBool(AppConstants.keyStrictMode, settings.strictMode),
      _storage.setString('selected_profile_id', settings.selectedProfileId),
      _storage.setString('menu_bar_style', settings.menuBarStyle),
    ]);
  }
}
