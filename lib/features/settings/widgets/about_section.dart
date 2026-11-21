import 'package:flutter/cupertino.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:breakmate/core/config/flavor_config.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/core/errors/error_handler.dart';
import 'package:breakmate/shared/widgets/themed_app_icon.dart';

/// Settings > About: version/build info and external links.
class AboutSection extends StatefulWidget {
  final SettingsModel settings;
  final ValueChanged<SettingsModel> onSave;

  const AboutSection({super.key, required this.settings, required this.onSave});

  @override
  State<AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends State<AboutSection> {
  String _version = '1.0.0';
  String _buildNumber = '1';

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = info.version;
          _buildNumber = info.buildNumber;
        });
      }
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const ThemedAppIcon.badge(size: 56, showDevBadge: true),
            const SizedBox(width: AppTheme.space16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    FlavorConfig.isDevelopment ? 'BreakMate dev' : 'BreakMate',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: AppTheme.space4),
                  Text(
                    'Break reminders for your eyes, posture and focus',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space32),

        sectionHeader('App info'),
        buildCard([
          valueRow('Version', '$_version (build $_buildNumber)'),
          divider(),
          buildListRow(
            'Creator',
            'Bijith P N, bijith.in',
            null,
            null,
            onTap: () => _launchUrl('https://bijith.in'),
          ),
          divider(),
          buildListRow(
            'Official website',
            'Visit breakmate.app',
            null,
            null,
            onTap: () => _launchUrl('https://breakmate.vercel.app'),
          ),
          divider(),
          buildListRow(
            'Report a bug',
            'Open an issue on GitHub',
            null,
            null,
            onTap: () =>
                _launchUrl('https://github.com/bijithpn/standup/issues'),
          ),
          divider(),
          buildListRow(
            'Support development',
            'BreakMate stays ad-free',
            null,
            null,
            onTap: () => _launchUrl('https://buymeacoffee.com/bijithpn'),
          ),
        ]),
      ],
    );
  }
}
