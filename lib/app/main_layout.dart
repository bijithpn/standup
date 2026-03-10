import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:standup/ui/theme/app_theme.dart';
import 'package:standup/features/settings/settings_page.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _pageIndex = 0;

  @override
  Widget build(BuildContext context) {
    return MacosWindow(
      backgroundColor: AppTheme.contentBackground,
      sidebar: Sidebar(
        minWidth: 200,
        // backgroundColor: AppTheme.sidebarBackground,
        top: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.accentColor, AppTheme.accentColor.withOpacity(0.7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentColor.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(CupertinoIcons.infinite, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                    const Text.rich(
                      TextSpan(
                        text: 'Break',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                        children: [
                          TextSpan(
                            text: 'Mate',
                            style: TextStyle(color: AppTheme.accentColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 30),
          ],
        ),
        builder: (context, scrollController) {
          return SidebarItems(
            currentIndex: _pageIndex,
            onChanged: (i) => setState(() => _pageIndex = i),
            scrollController: scrollController,
            items: const [
              SidebarItem(
                leading: MacosIcon(CupertinoIcons.settings),
                label: Text('General'),
              ),
              SidebarItem(
                leading: MacosIcon(CupertinoIcons.pause),
                label: Text('Breaks'),
              ),
              SidebarItem(
                leading: MacosIcon(CupertinoIcons.person_crop_circle),
                label: Text('Profiles'),
              ),
              SidebarItem(
                leading: MacosIcon(CupertinoIcons.viewfinder),
                label: Text('Focus Mode'),
              ),
              SidebarItem(
                leading: MacosIcon(CupertinoIcons.bolt),
                label: Text('Flash Reminder'),
              ),
              SidebarItem(
                leading: MacosIcon(CupertinoIcons.bell),
                label: Text('Notifications'),
              ),
              SidebarItem(
                leading: MacosIcon(CupertinoIcons.sportscourt),
                label: Text('Exercises'),
              ),
              SidebarItem(
                leading: MacosIcon(CupertinoIcons.clock),
                label: Text('Clock Out'),
              ),
              SidebarItem(
                leading: MacosIcon(CupertinoIcons.graph_square),
                label: Text('Statistics'),
              ),
            ],
          );
        },
        bottom: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildSidebarAction(CupertinoIcons.info, 'About', () => setState(() => _pageIndex = 9)),
            ],
          ),
        ),
      ),
      child: IndexedStack(
        index: _pageIndex,
        children: const [
          SettingsPage(section: 'General'),
          SettingsPage(section: 'Breaks'),
          SettingsPage(section: 'Profiles'),
          SettingsPage(section: 'Focus Mode'),
          SettingsPage(section: 'Flash Reminder'),
          SettingsPage(section: 'Notifications'),
          SettingsPage(section: 'Exercises'),
          SettingsPage(section: 'Clock Out'),
          SettingsPage(section: 'Statistics'),
          SettingsPage(section: 'About'),
        ],
      ),
    );
  }

  Widget _buildSidebarAction(IconData icon, String label, VoidCallback onTap) {
    return MacosListTile(
      leading: MacosIcon(icon, size: 16),
      title: Text(label, style: AppTheme.sidebarItemStyle),
      onClick: onTap,
    );
  }
}

class PlaceholderSection extends StatelessWidget {
  final String title;
  const PlaceholderSection({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return MacosScaffold(
      toolBar: ToolBar(
        title: Text(title),
        titleWidth: 200,
        // backgroundColor: AppTheme.contentBackground,
      ),
      children: [
        ContentArea(
          builder: (context, scrollController) {
            return Center(
              child: Text(
                'Coming soon: $title',
                style: AppTheme.tipStyle,
              ),
            );
          },
        ),
      ],
    );
  }
}
