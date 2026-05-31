import 'dart:async';
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/core/utils/toast.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:breakmate/features/companion/controllers/companion_overlay_controller.dart';
import 'package:breakmate/app/dependency_injection.dart';

import 'package:breakmate/features/settings/widgets/general_section.dart';
import 'package:breakmate/features/settings/presentation/sections/breaks_settings_section.dart';
import 'package:breakmate/features/settings/presentation/sections/focus_detection_section.dart';
import 'package:breakmate/features/settings/widgets/notifications_section.dart';
import 'package:breakmate/features/settings/presentation/sections/exercises_section.dart';
import 'package:breakmate/features/settings/presentation/sections/clock_out_section.dart';
import 'package:breakmate/features/settings/widgets/update_section.dart';
import 'package:breakmate/features/settings/widgets/about_section.dart';
import 'package:breakmate/features/settings/widgets/goals_section.dart';
import 'package:breakmate/features/settings/widgets/privacy_section.dart';
import 'package:breakmate/features/settings/presentation/sections/analytics_settings_section.dart';
import 'package:breakmate/features/settings/presentation/sections/companion_settings_section.dart';
import 'package:breakmate/features/settings/presentation/sections/data_management_section.dart';

class SettingsPage extends StatefulWidget {
  final String section;
  const SettingsPage({super.key, required this.section});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late SettingsModel _settings;
  Timer? _saveDebounceTimer;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final repo = Provider.of<SettingsRepository>(context, listen: false);
    _settings = repo.currentSettings;
  }

  @override
  void dispose() {
    _saveDebounceTimer?.cancel();
    super.dispose();
  }

  void _save(SettingsModel updated) {
    try {
      setState(() => _settings = updated);

      _saveDebounceTimer?.cancel();
      _saveDebounceTimer = Timer(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        final repo = Provider.of<SettingsRepository>(context, listen: false);
        repo.save(updated);
        Provider.of<BreakController>(context, listen: false).refreshSettings();
      });
    } catch (e) {
      if (mounted) {
        Toast.showError(context, 'Failed to save settings: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 600;
        final horizontalPadding = isSmallScreen ? 16.0 : 40.0;
        final verticalPadding = isSmallScreen ? 20.0 : 32.0;

        Widget buildContent(ScrollController? scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isSmallScreen ? double.infinity : 760,
                ),
                child: _buildContentShell(),
              ),
            ),
          );
        }

        if (isSmallScreen) {
          return Scaffold(
            backgroundColor: AppTheme.contentBackground,
            body: buildContent(null),
          );
        }

        return MacosScaffold(
          backgroundColor: AppTheme.contentBackground,
          toolBar: ToolBar(
            title: Text(
              _sectionDisplayName(widget.section),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            titleWidth: 260,
            actions: [],
          ),
          children: [
            ContentArea(
              builder: (context, scrollController) =>
                  buildContent(scrollController),
            ),
          ],
        );
      },
    );
  }

  String _sectionDisplayName(String section) {
    switch (section) {
      case 'Breaks & Profiles':
        return 'Breaks';
      case 'Intelligent Detection':
        return 'Focus mode';
      case 'Companion':
        return 'Companion';
      default:
        return section;
    }
  }

  Widget _buildContent() {
    switch (widget.section) {
      case 'General':
        return GeneralSection(settings: _settings, onSave: _save);
      case 'Breaks':
      case 'Breaks & Profiles':
      case 'Profiles':
        return BreaksSettingsSection(settings: _settings, onSave: _save);
      case 'Intelligent Detection':
      case 'Focus Mode':
        return FocusDetectionSection(settings: _settings, onSave: _save);
      case 'Notifications':
        return NotificationsSection(settings: _settings, onSave: _save);
      case 'Exercises':
        return ExercisesSection(settings: _settings, onSave: _save);
      case 'Clock Out':
        return ClockOutSection(settings: _settings, onSave: _save);
      case 'Updates':
        return UpdateSection(settings: _settings, onSave: _save);
      case 'About':
        return AboutSection(settings: _settings, onSave: _save);
      case 'Statistics':
        return Consumer<StatsService>(
          builder: (context, statsService, _) {
            return AnalyticsSettingsSection(stats: statsService.load());
          },
        );
      case 'Companion':
        return CompanionSettingsSection(
          controller: sl<CompanionOverlayController>(),
        );
      case 'Goals':
        return const GoalsSection();
      case 'Privacy':
        return const PrivacySection();
      case 'Data & Backup':
        return const DataManagementSection();
      default:
        return Center(
          child: Text(
            'Coming soon: ${widget.section}',
            style: AppTheme.tipStyle,
          ),
        );
    }
  }

  Widget _buildContentShell() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSettingsTools(),
        if (_settingsWarnings.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildSettingsWarnings(),
        ],
        const SizedBox(height: 20),
        if (_searchQuery.trim().isNotEmpty) ...[
          _buildSearchSummary(),
          const SizedBox(height: 20),
        ],
        _buildContent(),
      ],
    );
  }

  Widget _buildSettingsTools() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search settings, permissions, companion, breaks...',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              filled: true,
              fillColor: AppTheme.surfaceElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.accent),
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Current section: ${_sectionDisplayName(widget.section)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _resetCurrentSection,
                icon: const Icon(Icons.restore_rounded, size: 16),
                label: const Text('Reset section'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSummary() {
    final query = _searchQuery.trim().toLowerCase();
    final matches = _settingsSearchIndex.entries
        .where((entry) {
          final haystack = '${entry.key} ${entry.value.join(' ')}'
              .toLowerCase();
          return haystack.contains(query);
        })
        .map((entry) => entry.key)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.16)),
      ),
      child: Text(
        matches.isEmpty
            ? 'No exact settings match for "$_searchQuery". Try words like break, strict, calendar, companion, notification, privacy, or backup.'
            : 'Matching sections: ${matches.join(', ')}',
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
          height: 1.35,
        ),
      ),
    );
  }

  List<String> get _settingsWarnings {
    final warnings = <String>[];
    if (_settings.longBreakIntervalMinutes <=
        _settings.shortBreakIntervalMinutes) {
      warnings.add(
        'Long break interval should be greater than the short break interval.',
      );
    }
    if (_settings.intensityLevel == 'locked' && !_settings.strictMode) {
      warnings.add('Locked intensity works best with strict mode enabled.');
    }
    if (_settings.calendarEnabled &&
        (!_settings.detectMeetings && !_settings.detectVideoCalls)) {
      warnings.add(
        'Calendar planning is enabled, but meeting detection is disabled.',
      );
    }
    if (!_settings.soundEnabled && _settings.playMusicDuringBreak) {
      warnings.add('Break music is enabled while app sound is disabled.');
    }
    return warnings;
  }

  Widget _buildSettingsWarnings() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: AppTheme.warning,
              ),
              SizedBox(width: 8),
              Text(
                'Settings need attention',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final warning in _settingsWarnings)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                warning,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Map<String, List<String>> get _settingsSearchIndex => const {
    'General': ['startup', 'quiet mode', 'idle', 'reset', 'focus'],
    'Breaks': [
      'profile',
      'interval',
      'duration',
      'strict',
      'locked',
      'template',
      'music',
    ],
    'Focus Mode': ['meeting', 'calendar', 'detection', 'video call', 'focus'],
    'Notifications': ['sound', 'notification', 'posture', 'eye blink'],
    'Exercises': ['stretch', 'breathing', 'eye rest', 'wellness'],
    'Clock Out': ['work hours', 'wind down', 'end of day'],
    'Companion': ['pet', 'cat', 'dog', 'click-through', 'low-distraction'],
    'Goals': ['daily focus', 'break target', 'sitting', 'consistency'],
    'Privacy': ['local data', 'permissions', 'tracking'],
    'Data & Backup': ['export', 'import', 'backup', 'restore'],
    'Updates': ['release', 'sparkle', 'version'],
    'About': ['license', 'credits'],
  };

  void _resetCurrentSection() {
    const defaults = SettingsModel();
    final section = _sectionDisplayName(widget.section);

    if (section == 'Companion') {
      final controller = sl<CompanionOverlayController>();
      unawaited(controller.toggleCompanion(defaults.companionEnabled));
      unawaited(controller.changeTheme(defaults.companionPetTheme));
      unawaited(controller.changePetName(defaults.companionPetName));
      unawaited(controller.changeScale(defaults.companionScale));
      unawaited(controller.setLowDistractionMode(false));
      unawaited(controller.changeClickThrough(defaults.companionClickThrough));
      unawaited(controller.changeFollowMouse(defaults.companionFollowMouse));
      unawaited(
        controller.changePreviewBackground(defaults.companionPreviewBackground),
      );
      if (mounted) Toast.showSuccess(context, 'Companion settings reset');
      return;
    }

    SettingsModel updated = _settings;
    switch (section) {
      case 'General':
        updated = _settings.copyWith(
          autoStart: defaults.autoStart,
          quietModeEnabled: defaults.quietModeEnabled,
          quietModePreset: defaults.quietModePreset,
          pauseTimerAfterMinutes: defaults.pauseTimerAfterMinutes,
          resetTimerAfterMinutes: defaults.resetTimerAfterMinutes,
        );
        break;
      case 'Breaks':
        updated = _settings.copyWith(
          selectedProfileId: defaults.selectedProfileId,
          shortBreakIntervalMinutes: defaults.shortBreakIntervalMinutes,
          shortBreakDurationSeconds: defaults.shortBreakDurationSeconds,
          preBreakWarningSeconds: defaults.preBreakWarningSeconds,
          longBreakIntervalMinutes: defaults.longBreakIntervalMinutes,
          longBreakDurationMinutes: defaults.longBreakDurationMinutes,
          intensityLevel: defaults.intensityLevel,
          strictMode: defaults.strictMode,
          showOnAllDisplays: defaults.showOnAllDisplays,
          breakTheme: defaults.breakTheme,
          breakTemplate: defaults.breakTemplate,
          playMusicDuringBreak: defaults.playMusicDuringBreak,
        );
        break;
      case 'Focus mode':
        updated = _settings.copyWith(
          detectMeetings: defaults.detectMeetings,
          detectVideoCalls: defaults.detectVideoCalls,
          respectFocusMode: defaults.respectFocusMode,
          focusModeEnabled: defaults.focusModeEnabled,
          calendarEnabled: defaults.calendarEnabled,
        );
        break;
      case 'Notifications':
        updated = _settings.copyWith(
          notificationsEnabled: defaults.notificationsEnabled,
          soundEnabled: defaults.soundEnabled,
          postureReminderEnabled: defaults.postureReminderEnabled,
          eyeBlinkReminderEnabled: defaults.eyeBlinkReminderEnabled,
        );
        break;
      default:
        Toast.showSuccess(context, 'No reset defaults for $section');
        return;
    }

    _save(updated);
    Toast.showSuccess(context, '$section settings reset');
  }
}
