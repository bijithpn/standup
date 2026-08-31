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
import 'package:breakmate/features/themes/presentation/theme_settings_section.dart';

class SettingsPage extends StatefulWidget {
  final String section;
  const SettingsPage({super.key, required this.section});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late SettingsModel _settings;
  Timer? _saveDebounceTimer;

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
          return ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: SingleChildScrollView(
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
              style: TextStyle(
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
      case 'Themes':
      case 'Themes & Styling':
        return const ThemeSettingsSection();
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
        if (_settingsWarnings.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildSettingsWarnings(),
        ],
        const SizedBox(height: 20),
        _buildContent(),
      ],
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
          Row(
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
                style: TextStyle(
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
}
