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
    (label: 'Smart Detect', icon: CupertinoIcons.eye_solid, section: 'Intelligent Detection'),
    (label: 'Reminders', icon: CupertinoIcons.bolt_fill, section: 'Flash Reminder'),
    (label: 'Clock Out', icon: CupertinoIcons.moon_fill, section: 'Clock Out'),
    (label: 'Exercises', icon: CupertinoIcons.person_crop_circle_badge_exclam, section: 'Exercises'),
    (label: 'Insights', icon: CupertinoIcons.chart_bar_fill, section: 'Statistics'),
    (label: 'Articles', icon: CupertinoIcons.news, section: 'Blog'),
    (label: 'Settings', icon: CupertinoIcons.settings_solid, section: 'General'),
  ];

  @override
  Widget build(BuildContext context) {
    return MacosWindow(
      backgroundColor: AppTheme.contentBackground,
      sidebar: Sidebar(
        minWidth: 200,
        bottom: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(CupertinoIcons.infinite, color: AppTheme.accentColor, size: 16),
              SizedBox(width: 8),
              Text('BreakMate', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        builder: (context, controller) {
          return SidebarItems(
            currentIndex: _pageIndex,
            onChanged: (i) => setState(() => _pageIndex = i),
            scrollController: controller,
            itemSize: SidebarItemSize.large,
            items: _navItems.map((item) {
              return SidebarItem(
                leading: MacosIcon(item.icon, size: 20),
                label: Text(item.label, style: AppTheme.sidebarItemStyle),
              );
            }).toList(),
          );
        },
      ),
      child: _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    return IndexedStack(
      index: _pageIndex,
      children: [
        const CompanionDashboard(),
        const SettingsPage(section: 'Breaks & Profiles'),
        const SettingsPage(section: 'Intelligent Detection'),
        const SettingsPage(section: 'Flash Reminder'),
        const SettingsPage(section: 'Clock Out'),
        const SettingsPage(section: 'Exercises'),
        const SettingsPage(section: 'Statistics'),
        const WellnessArticlesPage(),
        const SettingsPage(section: 'General'),
      ],
    );
  }
}
