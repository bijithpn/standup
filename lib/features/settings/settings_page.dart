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
                child: _buildContent(),
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
              builder: (context, scrollController) => buildContent(scrollController),
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
}
