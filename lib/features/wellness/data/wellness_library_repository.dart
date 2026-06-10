import 'package:flutter/foundation.dart';
import 'package:breakmate/features/settings/exercise_model.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

class WellnessLibraryRepository extends ChangeNotifier {
  final SettingsRepository _settingsRepo;
  List<ExerciseModel> _exercises = [];

  WellnessLibraryRepository({required SettingsRepository settingsRepo})
    : _settingsRepo = settingsRepo {
    _load();
  }

  List<ExerciseModel> get allExercises => _exercises;
  List<ExerciseModel> get visibleExercises =>
      _exercises.where((e) => !e.isHidden).toList();
  List<ExerciseModel> get favorites =>
      _exercises.where((e) => e.isFavorite).toList();

  void _load() {
    _exercises = _settingsRepo.getExercises();
    notifyListeners();
  }

  Future<void> toggleFavorite(String id) async {
    final index = _exercises.indexWhere((e) => e.id == id);
    if (index != -1) {
      _exercises[index] = _exercises[index].copyWith(
        isFavorite: !_exercises[index].isFavorite,
      );
      await _syncWithSettings();
    }
  }

  Future<void> toggleHidden(String id) async {
    final index = _exercises.indexWhere((e) => e.id == id);
    if (index != -1) {
      _exercises[index] = _exercises[index].copyWith(
        isHidden: !_exercises[index].isHidden,
      );
      await _syncWithSettings();
    }
  }

  Future<void> _syncWithSettings() async {
    final newSettings = _settingsRepo.currentSettings.copyWith(
      exercises: _exercises,
    );
    await _settingsRepo.save(newSettings);
    notifyListeners();
  }

  ExerciseModel? getNextSuggested(String lastId) {
    final pool = visibleExercises.isEmpty
        ? ExerciseModel.defaults
        : visibleExercises;
    if (pool.isEmpty) return null;

    final favPool = pool.where((e) => e.isFavorite).toList();
    final selectionPool = favPool.isNotEmpty ? favPool : pool;

    final index = selectionPool.indexWhere((e) => e.id == lastId);
    final nextIndex = (index + 1) % selectionPool.length;
    return selectionPool[nextIndex];
  }
}
