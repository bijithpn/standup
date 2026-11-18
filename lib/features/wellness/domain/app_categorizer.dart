import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';

enum AppCategory { coding, writing, browsing, meeting, design, general }

/// Maps an app's name/bundle id to a coarse category via substring heuristics (first match wins).
class AppCategorizer {
  AppCategorizer._();

  static AppCategory categorize({
    required String name,
    required String bundleId,
  }) {
    final lowerName = name.toLowerCase();
    final lowerBundleId = bundleId.toLowerCase();

    if (lowerName.contains('xcode') ||
        lowerName.contains('studio') ||
        lowerName.contains('vscode') ||
        lowerBundleId.contains('code')) {
      return AppCategory.coding;
    }
    if (lowerName.contains('word') ||
        lowerName.contains('notes') ||
        lowerName.contains('writer') ||
        lowerName.contains('pages')) {
      return AppCategory.writing;
    }
    if (lowerName.contains('chrome') ||
        lowerName.contains('safari') ||
        lowerName.contains('firefox') ||
        lowerName.contains('browser')) {
      return AppCategory.browsing;
    }
    if (lowerName.contains('zoom') ||
        lowerName.contains('teams') ||
        lowerName.contains('meet') ||
        lowerName.contains('slack')) {
      return AppCategory.meeting;
    }
    if (lowerName.contains('figma') ||
        lowerName.contains('photoshop') ||
        lowerName.contains('illustrator') ||
        lowerName.contains('sketch')) {
      return AppCategory.design;
    }

    return AppCategory.general;
  }
}

extension AppCategoryUi on AppCategory {
  String get label {
    switch (this) {
      case AppCategory.coding:
        return 'Coding';
      case AppCategory.writing:
        return 'Writing';
      case AppCategory.browsing:
        return 'Browsing';
      case AppCategory.meeting:
        return 'Meetings';
      case AppCategory.design:
        return 'Design';
      case AppCategory.general:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case AppCategory.coding:
        return CupertinoIcons.chevron_left_slash_chevron_right;
      case AppCategory.writing:
        return CupertinoIcons.doc_text;
      case AppCategory.browsing:
        return CupertinoIcons.globe;
      case AppCategory.meeting:
        return CupertinoIcons.video_camera;
      case AppCategory.design:
        return CupertinoIcons.paintbrush;
      case AppCategory.general:
        return CupertinoIcons.app;
    }
  }

  Color get color {
    switch (this) {
      case AppCategory.coding:
        return AppTheme.info;
      case AppCategory.writing:
        return AppTheme.accent;
      case AppCategory.browsing:
        return AppTheme.warning;
      case AppCategory.meeting:
        return AppTheme.success;
      case AppCategory.design:
        return AppTheme.primaryLight;
      case AppCategory.general:
        return AppTheme.textMuted;
    }
  }
}
