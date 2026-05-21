import 'package:flutter/cupertino.dart';
import 'package:standup/features/settings/settings_model.dart';
import 'package:standup/features/settings/widgets/settings_widgets.dart';
import 'package:standup/shared/theme/app_theme.dart';
import 'package:standup/app/dependency_injection.dart';
import 'package:standup/core/services/app_navigation_service.dart';

class AboutSection extends StatelessWidget {
  final SettingsModel settings;
  final ValueChanged<SettingsModel> onSave;

  const AboutSection({super.key, required this.settings, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader('About BreakMate'),
        buildCard([
          _buildVersion(),
          divider(),
          _buildCheckUpdates(),
          divider(),
          _buildWebsite(),
          divider(),
          _buildDocumentation(),
          divider(),
          _buildReportIssue(),
        ]),
      ],
    );
  }

  Widget _buildVersion() {
    return buildListRow(
      'Version',
      '1.0.0 (Build 2024.12)',
      null,
      CupertinoIcons.info,
      null,
    );
  }

  Widget _buildCheckUpdates() {
    return buildListRow(
      'Check for Updates',
      'Ensure you have the latest features',
      null,
      CupertinoIcons.cloud_download,
      null,
      onTap: () {
        sl<AppNavigationService>().openSection('Check Updates');
      },
      trailing: const Icon(
        CupertinoIcons.chevron_right,
        size: 14,
        color: AppTheme.accentColor,
      ),
    );
  }

  Widget _buildWebsite() {
    return buildListRow(
      'Website',
      'Visit breakmate.app',
      null,
      CupertinoIcons.globe,
      null,
      onTap: () {
        sl<AppNavigationService>().openSection('Website');
      },
      trailing: const Icon(
        CupertinoIcons.chevron_right,
        size: 14,
        color: AppTheme.accentColor,
      ),
    );
  }

  Widget _buildDocumentation() {
    return buildListRow(
      'Documentation',
      'Learn how to use BreakMate',
      null,
      CupertinoIcons.book,
      null,
      onTap: () {
        sl<AppNavigationService>().openSection('Documentation');
      },
      trailing: const Icon(
        CupertinoIcons.chevron_right,
        size: 14,
        color: AppTheme.accentColor,
      ),
    );
  }

  Widget _buildReportIssue() {
    return buildListRow(
      'Report an Issue',
      'Help us improve BreakMate',
      null,
      CupertinoIcons.exclamationmark_triangle,
      null,
      onTap: () {
        sl<AppNavigationService>().openSection('Report Issue');
      },
      trailing: const Icon(
        CupertinoIcons.chevron_right,
        size: 14,
        color: AppTheme.accentColor,
      ),
    );
  }
}
