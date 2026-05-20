import 'package:flutter/cupertino.dart';
import 'package:standup/features/settings/settings_model.dart';
import 'package:standup/features/settings/widgets/settings_widgets.dart';
import 'package:standup/shared/theme/app_theme.dart';
import 'package:standup/app/dependency_injection.dart';
import 'package:standup/core/services/app_navigation_service.dart';
import 'package:standup/features/menu_bar/tray_manager_service.dart';

class AboutSection extends StatelessWidget {
  final SettingsModel settings;
  final ValueChanged<SettingsModel> onSave;

  const AboutSection({
    super.key,
    required this.settings,
    required this.onSave,
  });

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
        const SizedBox(height: 48),
        sectionHeader('Companion'),
        const SizedBox(height: 24),
        buildCard([
          _buildCompanionToggle(),
          divider(),
          _buildCompanionCatTheme(),
          divider(),
          _buildCompanionScale(),
          divider(),
          _buildCompanionClickThrough(),
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

  Widget _buildCompanionToggle() {
    return toggleRow(
      'Desktop Companion',
      'Show a draggable pet companion on your desktop',
      settings.companionEnabled,
      (v) {
        onSave(settings.copyWith(companionEnabled: v));
        sl<TrayManagerService>().triggerActionAnimation();
      },
    );
  }

  Widget _buildCompanionCatTheme() {
    return buildListRow(
      'Companion Theme',
      'Choose your companion appearance',
      null,
      CupertinoIcons.paintbrush,
      null,
      trailing: inlineDropdown(
        settings.companionCatTheme,
        ['grey_cat', 'orange_cat', 'black_cat', 'white_cat'],
        (v) {
          onSave(settings.copyWith(companionCatTheme: v ?? 'grey_cat'));
          sl<TrayManagerService>().triggerActionAnimation();
        },
      ),
    );
  }

  Widget _buildCompanionScale() {
    return sliderRow(
      'Companion Size',
      settings.companionScale,
      (v) => onSave(settings.copyWith(companionScale: v)),
      min: 3.0,
      max: 10.0,
    );
  }

  Widget _buildCompanionClickThrough() {
    return toggleRow(
      'Click-Through Mode',
      'Allow clicks to pass through the companion',
      settings.companionClickThrough,
      (v) {
        onSave(settings.copyWith(companionClickThrough: v));
        sl<TrayManagerService>().triggerActionAnimation();
      },
    );
  }
}
