import 'package:breakmate/features/settings/exercise_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

import '../core/services/timer_engine_drift_test.dart' show FakeStorageService;

/// Settings repository backed by memory only (the real one needs ObjectBox).
/// `save` notifies listeners exactly like the real one.
class InMemorySettingsRepository extends SettingsRepository {
  SettingsModel _settings;

  InMemorySettingsRepository([SettingsModel? initial])
    : _settings = initial ?? const SettingsModel(),
      super(storage: FakeStorageService());

  @override
  SettingsModel get currentSettings => _settings;

  @override
  Future<void> save(SettingsModel settings) async {
    _settings = settings;
    notifyListeners();
  }

  @override
  List<ExerciseModel> getExercises() => _settings.exercises.isEmpty
      ? ExerciseModel.defaults
      : _settings.exercises;
}
