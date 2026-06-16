import 'package:breakmate/core/native/app_tracking_service.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/exercise_model.dart';

enum WellnessContext { coding, writing, browsing, meeting, design, general }

class WellnessEngine {
  final AppTrackingService _appTracking;

  WellnessEngine({required AppTrackingService appTracking})
    : _appTracking = appTracking;

  Future<WellnessContext> getCurrentContext() async {
    final activeApp = await _appTracking.getActiveApp();
    if (activeApp == null) return WellnessContext.general;

    final name = activeApp.name.toLowerCase();
    final bundleId = activeApp.bundleId.toLowerCase();

    if (name.contains('xcode') ||
        name.contains('studio') ||
        name.contains('vscode') ||
        bundleId.contains('code')) {
      return WellnessContext.coding;
    }
    if (name.contains('word') ||
        name.contains('notes') ||
        name.contains('writer') ||
        name.contains('pages')) {
      return WellnessContext.writing;
    }
    if (name.contains('chrome') ||
        name.contains('safari') ||
        name.contains('firefox') ||
        name.contains('browser')) {
      return WellnessContext.browsing;
    }
    if (name.contains('zoom') ||
        name.contains('teams') ||
        name.contains('meet') ||
        name.contains('slack')) {
      return WellnessContext.meeting;
    }
    if (name.contains('figma') ||
        name.contains('photoshop') ||
        name.contains('illustrator') ||
        name.contains('sketch')) {
      return WellnessContext.design;
    }

    return WellnessContext.general;
  }

  Future<String> getSuggestedBreakTip(BreakType type) async {
    final context = await getCurrentContext();

    switch (context) {
      case WellnessContext.coding:
        return type == BreakType.short
            ? "Posture check! Roll your shoulders back to counter 'coder's hunch'."
            : "Long session of deep focus. Take a walk to clear your mind and rest your eyes.";
      case WellnessContext.writing:
        return "Wrist relief: Shake out your hands and stretch your forearms.";
      case WellnessContext.browsing:
        return "20-20-20 rule: Look at something 20 feet away for 20 seconds to reduce eye strain.";
      case WellnessContext.meeting:
        return "After-meeting reset: Take 3 deep breaths and stand up for a moment.";
      case WellnessContext.design:
        return "Neck stretch: Gently tilt your head side to side to release tension from detailed work.";
      case WellnessContext.general:
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
      case WellnessContext.coding:
        targetCategory = ExerciseCategory.posture;
        break;
      case WellnessContext.writing:
        targetCategory = ExerciseCategory.stretch;
        break; // No wrist cat, use stretch
      case WellnessContext.browsing:
        targetCategory = ExerciseCategory.eyeRest;
        break;
      case WellnessContext.design:
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
