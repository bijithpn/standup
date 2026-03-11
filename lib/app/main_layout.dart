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
  bool _sidebarCollapsed = false;

  final List<({String label, IconData icon, String section})> _navItems = [
    (label: 'General', icon: CupertinoIcons.settings, section: 'General'),
    (label: 'Flash', icon: CupertinoIcons.bolt_fill, section: 'Flash Reminder'),
    (
      label: 'Breaks',
      icon: CupertinoIcons.pause_fill,
      section: 'Breaks & Profiles',
    ),
    (label: 'Focus', icon: CupertinoIcons.timer, section: 'Focus Mode'),
    (label: 'Alerts', icon: CupertinoIcons.bell_fill, section: 'Notifications'),
    (
      label: 'Exercise',
      icon: CupertinoIcons.sportscourt_fill,
      section: 'Exercises',
    ),
    (label: 'Clock', icon: CupertinoIcons.clock_fill, section: 'Clock Out'),
    (
      label: 'Stats',
      icon: CupertinoIcons.chart_bar_fill,
      section: 'Statistics',
    ),
    (label: 'About', icon: CupertinoIcons.info_circle_fill, section: 'About'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900 || constraints.maxHeight < 650) {
          return _buildTopLayout();
        }
        return _buildSidebarLayout();
      },
    );
  }

  /*
  -----------------------------------------
  SIDEBAR LAYOUT (LARGE WINDOWS)
  -----------------------------------------
  */

  Widget _buildSidebarLayout() {
    return MacosWindow(
      backgroundColor: AppTheme.contentBackground,
      sidebar: Sidebar(
        minWidth: _sidebarCollapsed ? 80 : 240,
        top: Column(
          children: [
            const SizedBox(height: 24),
            _buildLogo(center: true),
            const SizedBox(height: 24),
          ],
        ),
        builder: (context, controller) {
          final sidebarItems = _navItems.take(_navItems.length - 1).toList();
          final safeIndex = _pageIndex >= sidebarItems.length
              ? sidebarItems.length - 1
              : _pageIndex;

          return SidebarItems(
            currentIndex: safeIndex,
            onChanged: (i) => setState(() => _pageIndex = i),
            scrollController: controller,
            itemSize: SidebarItemSize.large,
            items: sidebarItems.map((item) {
              return SidebarItem(
                leading: MacosIcon(item.icon),
                label: _sidebarCollapsed
                    ? const SizedBox.shrink()
                    : Text(item.label, style: AppTheme.sidebarItemStyle),
              );
            }).toList(),
          );
        },
        bottom: Padding(
          padding: const EdgeInsets.all(12),
          child: MacosListTile(
            leading: const MacosIcon(CupertinoIcons.info_circle_fill),
            title: const Text("About"),
            onClick: () => setState(() => _pageIndex = _navItems.length - 1),
          ),
        ),
      ),
      child: _buildMainContent(),
    );
  }

  /*
  -----------------------------------------
  TOP NAV LAYOUT (SMALL WINDOWS)
  -----------------------------------------
  */

  Widget _buildTopLayout() {
    final screenWidth = MediaQuery.of(context).size.width;

    return MacosScaffold(
      backgroundColor: AppTheme.contentBackground,
      toolBar: ToolBar(
        height: 110,
        centerTitle: true,
        title: SizedBox(
          width: screenWidth,
          child: Column(
            children: [
              _buildLogo(center: true),
              const SizedBox(height: 10),
              _buildScrollableNavigation(screenWidth),
            ],
          ),
        ),
      ),
      children: [ContentArea(builder: (context, _) => _buildMainContent())],
    );
  }

  /*
  -----------------------------------------
  HORIZONTAL SCROLL NAVIGATION
  -----------------------------------------
  */

  Widget _buildScrollableNavigation(double screenWidth) {
    return SizedBox(
      width: screenWidth,
      height: 60,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            const SizedBox(width: 12),
            ..._navItems.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final selected = _pageIndex == i;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _pageIndex = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.accentColor
                          : AppTheme.cardBackground,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? AppTheme.accentColor
                            : AppTheme.borderColor,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item.icon,
                          size: 18,
                          color: selected
                              ? Colors.white
                              : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 13,
                            color: selected
                                ? Colors.white
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  /*
  -----------------------------------------
  LOGO
  -----------------------------------------
  */

  Widget _buildLogo({bool center = false}) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      child: Row(
        mainAxisAlignment: center
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.accentColor,
                  AppTheme.accentColor.withValues(alpha: 0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              CupertinoIcons.infinite,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Text.rich(
            TextSpan(
              text: "Break",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              children: const [
                TextSpan(
                  text: "Mate",
                  style: TextStyle(color: AppTheme.accentColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /*
  -----------------------------------------
  MAIN CONTENT
  -----------------------------------------
  */

  Widget _buildMainContent() {
    return IndexedStack(
      index: _pageIndex,
      children: _navItems
          .map((item) => SettingsPage(section: item.section))
          .toList(),
    );
  }
}
