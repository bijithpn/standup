import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

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
  String _appName = 'BreakMate';

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
          _appName = info.appName;
        });
      }
    } catch (_) {}
  }

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Premium stylized header logo block
        Center(
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Beautiful app icon simulated glow container
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentColor.withValues(alpha: 0.35),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(2.5), // Premium gradient border
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17.5),
                  child: Image.asset(
                    'assets/icons/app_icon.jpeg',
                    width: 67,
                    height: 67,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // App Title with premium gradient
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Colors.white, Color(0xFFE0E0E0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ).createShader(bounds),
                child: Text(
                  _appName,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Inter',
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'A premium desktop companion for your well-being.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),

        sectionHeader('Application Info'),
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
            'Creator: Bijith P N',
            'Visit portfolio: bijith.in',
            null,
            CupertinoIcons.person_circle,
            null,
            onTap: () => _launchUrl('https://bijith.in'),
            trailing: Icon(
              CupertinoIcons.link,
              size: 14,
              color: AppTheme.accentColor,
            ),
          ),
          divider(),
          buildListRow(
            'Official Website',
            'Visit breakmate.app',
            null,
            CupertinoIcons.globe,
            null,
            onTap: () => _launchUrl('https://breakmate.vercel.app'),
            trailing: Icon(
              CupertinoIcons.link,
              size: 14,
              color: AppTheme.accentColor,
            ),
          ),
          divider(),
          buildListRow(
            'Report Bug / Issue',
            'Help us improve BreakMate on GitHub',
            null,
            CupertinoIcons.exclamationmark_triangle,
            null,
            onTap: () => _launchUrl(
              'https://github.com/bijithintersmart/standup/issues',
            ),
            trailing: Icon(
              CupertinoIcons.link,
              size: 14,
              color: AppTheme.accentColor,
            ),
          ),
        ]),

        const SizedBox(height: 8),

        // Buy me a Coffee Premium CTA Card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Enjoying BreakMate?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  fontFamily: 'Inter',
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Support development and keep BreakMate ad-free by fueling my coffee mug.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontFamily: 'Inter',
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Custom interactive golden/amber gradient coffee button
              GestureDetector(
                onTap: () => _launchUrl('https://buymeacoffee.com/bijithpn'),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFFD15C), // Premium Warm Golden Yellow
                          Color(0xFFF39C12), // Honey Amber Orange
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFFF39C12,
                          ).withValues(alpha: 0.25),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.heart_fill,
                          color: Color(0xFF1A1A1A),
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Buy me a Coffee',
                          style: TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
