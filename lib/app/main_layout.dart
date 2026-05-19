import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:standup/app/dependency_injection.dart';
import 'package:standup/core/services/app_navigation_service.dart';
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
  late final AppNavigationService _navigationService;

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
  void initState() {
    super.initState();
    _navigationService = sl<AppNavigationService>();
    _navigationService.selectedSection.addListener(_handleExternalNavigation);
  }

  @override
  void dispose() {
    _navigationService.selectedSection.removeListener(_handleExternalNavigation);
    super.dispose();
  }

  void _handleExternalNavigation() {
    final section = _navigationService.selectedSection.value;
    final index = _navItems.indexWhere((item) => item.section == section);
    if (index != -1 && index != _pageIndex && mounted) {
      setState(() => _pageIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 750;
        
        if (isNarrow) {
          return _buildNarrowLayout();
        }
        
        return MacosWindow(
          backgroundColor: AppTheme.contentBackground,
          titleBar: const TitleBar(
            height: 52,
            dividerColor: Colors.transparent,
            centerTitle: true,
          ),
          sidebar: Sidebar(
            minWidth: 210,
            maxWidth: 250,
            bottom: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(CupertinoIcons.infinite, color: AppTheme.accentColor, size: 14),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'BreakMate',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
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
                    leading: MacosIcon(item.icon, size: 18),
                    label: Text(item.label, style: AppTheme.sidebarItemStyle),
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

  Widget _buildNarrowLayout() {
    return Scaffold(
      backgroundColor: AppTheme.contentBackground,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.sidebarBackground.withValues(alpha: 0.8),
            border: const Border(bottom: BorderSide(color: AppTheme.borderColor, width: 0.5)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu_rounded, color: AppTheme.accentColor, size: 20),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _navItems[_pageIndex].label,
                    style: AppTheme.headerStyle.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      drawer: Drawer(
        backgroundColor: AppTheme.sidebarBackground,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.only(top: 60, bottom: 20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.borderColor, width: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(CupertinoIcons.infinite, color: AppTheme.accentColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'BreakMate',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: _navItems.length,
                itemBuilder: (context, index) {
                  final item = _navItems[index];
                  final isSelected = _pageIndex == index;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: Icon(
                        item.icon,
                        size: 20,
                        color: isSelected ? AppTheme.accentColor : AppTheme.textSecondary,
                      ),
                      title: Text(
                        item.label,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppTheme.textSecondary,
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      selected: isSelected,
                      selectedTileColor: AppTheme.accentColor.withValues(alpha: 0.15),
                      onTap: () {
                        setState(() => _pageIndex = index);
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      body: _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(animation),
            child: child,
          ),
        );
      },
      child: IndexedStack(
        key: ValueKey(_pageIndex),
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
      ),
    );
  }
}
