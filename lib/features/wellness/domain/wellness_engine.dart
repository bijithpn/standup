import 'package:breakmate/core/native/app_tracking_service.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/exercise_model.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';

class WellnessEngine {
  final AppTrackingService _appTracking;

  WellnessEngine({required AppTrackingService appTracking})
    : _appTracking = appTracking;

  Future<AppCategory> getCurrentContext() async {
    final activeApp = await _appTracking.getActiveApp();
    if (activeApp == null) return AppCategory.general;

    return AppCategorizer.categorize(
      name: activeApp.name,
      bundleId: activeApp.bundleId,
    );
  }

  Future<String> getSuggestedBreakTip(BreakType type) async {
    final context = await getCurrentContext();

    switch (context) {
      case AppCategory.coding:
        return type == BreakType.short
            ? "Posture check! Roll your shoulders back to counter 'coder's hunch'."
            : "Long session of deep focus. Take a walk to clear your mind and rest your eyes.";
      case AppCategory.writing:
        return "Wrist relief: Shake out your hands and stretch your forearms.";
      case AppCategory.browsing:
        return "20-20-20 rule: Look at something 20 feet away for 20 seconds to reduce eye strain.";
      case AppCategory.meeting:
        return "After-meeting reset: Take 3 deep breaths and stand up for a moment.";
      case AppCategory.design:
        return "Neck stretch: Gently tilt your head side to side to release tension from detailed work.";
      case AppCategory.general:
        return type == BreakType.short
            ? "Quick break! Take a sip of water and stretch your legs."
            : "Time for a proper break. You've earned it!";
    }
  }

  Future<String> getSuggestedExerciseId(List<ExerciseModel> available) async {
    if (available.isEmpty) return '';
    final context = await getCurrentContext();

    ExerciseCategory targetCategory = ExerciseCategory.stretch;
    switch (context) {
      case AppCategory.coding:
        targetCategory = ExerciseCategory.posture;
        break;
      case AppCategory.writing:
        targetCategory = ExerciseCategory.stretch;
        break; // No wrist cat, use stretch
      case AppCategory.browsing:
        targetCategory = ExerciseCategory.eyeRest;
        break;
      case AppCategory.design:
        targetCategory = ExerciseCategory.stretch;
        break; // No neck cat, use stretch
      default:
        targetCategory = ExerciseCategory.stretch;
    }

    final matches = available
        .where((e) => e.category == targetCategory)
        .toList();
    if (matches.isNotEmpty) {
      matches.shuffle();
      return matches.first.id;
    }

    return available[DateTime.now().minute % available.length].id;
  }
}
