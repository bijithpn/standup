import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:standup/shared/theme/app_theme.dart';
import 'package:standup/features/settings/settings_page.dart';
import 'package:standup/features/wellness/presentation/wellness_articles_page.dart';
import 'package:standup/features/companion/presentation/companion_dashboard.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _pageIndex = 0;

  final List<({String label, IconData icon, String section})> _navItems = [
    (label: 'Companion', icon: CupertinoIcons.sparkles, section: 'Companion'),
    (label: 'Wellness', icon: CupertinoIcons.heart_fill, section: 'Breaks & Profiles'),
    (label: 'Reminders', icon: CupertinoIcons.bolt_fill, section: 'Flash Reminder'),
    (label: 'Insights', icon: CupertinoIcons.chart_bar_fill, section: 'Statistics'),
    (label: 'Articles', icon: CupertinoIcons.news, section: 'Blog'),
    (label: 'Settings', icon: CupertinoIcons.settings_solid, section: 'General'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 800;
        final sidebarWidth = isNarrow ? 72.0 : 240.0;

        return MacosWindow(
          backgroundColor: AppTheme.contentBackground,
          sidebar: Sidebar(
            minWidth: sidebarWidth,
            top: Column(
              children: [
                const SizedBox(height: 32),
                _buildLogo(isNarrow),
                const SizedBox(height: 32),
              ],
            ),
            builder: (context, controller) {
              return SidebarItems(
                currentIndex: _pageIndex,
                onChanged: (i) => setState(() => _pageIndex = i),
                scrollController: controller,
                itemSize: isNarrow ? SidebarItemSize.small : SidebarItemSize.large,
                items: _navItems.map((item) {
                  return SidebarItem(
                    leading: MacosIcon(item.icon, size: 20),
                    label: isNarrow ? const SizedBox.shrink() : Text(item.label, style: AppTheme.sidebarItemStyle),
                  );
                }).toList(),
              );
            },
          ),
          child: _buildMainContent(),
        );
      },
    );
  }

  Widget _buildLogo(bool isNarrow) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isNarrow ? 12 : 24),
      child: Row(
        mainAxisAlignment: isNarrow ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.accentColor, Color(0xFF0055FF)],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentColor.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(CupertinoIcons.infinite, color: Colors.white, size: 18),
          ),
          if (!isNarrow) ...[
            const SizedBox(width: 12),
            const Text(
              "BreakMate",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return IndexedStack(
      index: _pageIndex,
      children: [
        const CompanionDashboard(),
        SettingsPage(section: 'Breaks & Profiles'),
        SettingsPage(section: 'Flash Reminder'),
        SettingsPage(section: 'Statistics'),
        const WellnessArticlesPage(),
        SettingsPage(section: 'General'),
      ],
    );
  }
}
