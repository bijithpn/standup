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
        Center(
          child: Column(
            children: [
              const SizedBox(height: 12),
              const ThemedAppIcon.badge(size: 72, showDevBadge: true),
              const SizedBox(height: 16),
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                    fontFamily: 'Inter',
                  ),
                  children: [
                    const TextSpan(text: 'Break'),
                    TextSpan(
                      text: 'Mate',
                      style: TextStyle(color: AppTheme.accentColor),
                    ),
                    if (FlavorConfig.isDevelopment)
                      TextSpan(
                        text: ' dev',
                        style: TextStyle(color: AppTheme.error),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Break reminders for your eyes, posture and focus',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),

        sectionHeader('Application info'),
        buildCard([
          buildListRow(
            'Version',
            '$_version (Build $_buildNumber)',
            null,
            CupertinoIcons.info,
            null,
          ),
          divider(),
          buildListRow(
            'Creator',
            'Bijith P N, bijith.in',
            null,
            CupertinoIcons.person_circle,
            null,
            onTap: () => _launchUrl('https://bijith.in'),
            trailing: Icon(
              CupertinoIcons.link,
              size: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          divider(),
          buildListRow(
            'Official website',
            'Visit breakmate.app',
            null,
            CupertinoIcons.globe,
            null,
            onTap: () => _launchUrl('https://breakmate.vercel.app'),
            trailing: Icon(
              CupertinoIcons.link,
              size: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          divider(),
          buildListRow(
            'Report a bug',
            'Open an issue on GitHub',
            null,
            CupertinoIcons.exclamationmark_triangle,
            null,
            onTap: () =>
                _launchUrl('https://github.com/bijithpn/standup/issues'),
            trailing: Icon(
              CupertinoIcons.link,
              size: 16,
              color: AppTheme.textSecondary,
            ),
          ),
        ]),

        buildCard([
          buildListRow(
            'Support development',
            'BreakMate stays ad-free',
            null,
            CupertinoIcons.heart,
            null,
            onTap: () => _launchUrl('https://buymeacoffee.com/bijithpn'),
            trailing: Icon(
              CupertinoIcons.link,
              size: 16,
              color: AppTheme.textSecondary,
            ),
          ),
        ]),
        const SizedBox(height: 24),
      ],
    );
  }
}
