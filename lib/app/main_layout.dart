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
  bool _isMenuOpen = false;
  int? _hoveredIndex;
  late final AppNavigationService _navigationService;

  final List<({String label, IconData icon, String section})> _navItems = [
    (label: 'Companion', icon: CupertinoIcons.sparkles, section: 'Companion'),
    (
      label: 'Wellness',
      icon: CupertinoIcons.heart_fill,
      section: 'Breaks & Profiles',
    ),
    (
      label: 'Smart Detect',
      icon: CupertinoIcons.eye_solid,
      section: 'Intelligent Detection',
    ),
    (
      label: 'Reminders',
      icon: CupertinoIcons.bolt_fill,
      section: 'Flash Reminder',
    ),
    (label: 'Clock Out', icon: CupertinoIcons.moon_fill, section: 'Clock Out'),
    (
      label: 'Exercises',
      icon: CupertinoIcons.person_crop_circle_badge_exclam,
      section: 'Exercises',
    ),
    (
      label: 'Insights',
      icon: CupertinoIcons.chart_bar_fill,
      section: 'Statistics',
    ),
    (label: 'Articles', icon: CupertinoIcons.news, section: 'Blog'),
    (
      label: 'Settings',
      icon: CupertinoIcons.settings_solid,
      section: 'General',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _navigationService = sl<AppNavigationService>();
    _navigationService.selectedSection.addListener(_handleExternalNavigation);
  }

  @override
  void dispose() {
    _navigationService.selectedSection.removeListener(
      _handleExternalNavigation,
    );
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

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.02),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: isNarrow
              ? _buildNarrowLayout(key: const ValueKey('narrow'))
              : MacosWindow(
                  key: const ValueKey('wide'),
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
                              color: AppTheme.accentColor.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              CupertinoIcons.infinite,
                              color: AppTheme.accentColor,
                              size: 14,
                            ),
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
                        items: _navItems.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          final isHovered = _hoveredIndex == index;

                          return SidebarItem(
                            leading: MacosIcon(item.icon, size: 18),
                            label: MouseRegion(
                              onEnter: (_) =>
                                  setState(() => _hoveredIndex = index),
                              onExit: (_) =>
                                  setState(() => _hoveredIndex = null),
                              child: AnimatedScale(
                                scale: isHovered ? 1.02 : 1.0,
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOut,
                                child: Text(
                                  item.label,
                                  style: AppTheme.sidebarItemStyle,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  child: _buildMainContent(),
                ),
        );
      },
    );
  }

  Widget _buildNarrowLayout({Key? key}) {
    return Stack(
      key: key,
      children: [
        _buildMainContent(),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.sidebarBackground.withValues(alpha: 0.7),
              border: const Border(
                bottom: BorderSide(color: AppTheme.borderColor, width: 0.5),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _isMenuOpen = !_isMenuOpen),
                      child: const Icon(
                        CupertinoIcons.bars,
                        color: AppTheme.accentColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
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
        if (_isMenuOpen) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _isMenuOpen = false),
              child: Container(color: Colors.black.withValues(alpha: 0.2)),
            ),
          ),
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            child: AppTheme.glassContainer(
              opacity: 0.6,
              child: Container(
                width: 260,
                padding: const EdgeInsets.only(top: 60, left: 16, right: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24, left: 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor.withValues(
                                alpha: 0.2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              CupertinoIcons.infinite,
                              color: AppTheme.accentColor,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'BreakMate',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _navItems.length,
                        itemBuilder: (context, index) {
                          final item = _navItems[index];
                          final isSelected = _pageIndex == index;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _pageIndex = index;
                                  _isMenuOpen = false;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.accentColor.withValues(
                                          alpha: 0.2,
                                        )
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: isSelected
                                      ? Border.all(
                                          color: AppTheme.accentColor
                                              .withValues(alpha: 0.3),
                                          width: 0.5,
                                        )
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      item.icon,
                                      size: 18,
                                      color: isSelected
                                          ? AppTheme.accentColor
                                          : AppTheme.textSecondary,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      item.label,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : AppTheme.textSecondary,
                                        fontSize: 14,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMainContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(animation),
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
