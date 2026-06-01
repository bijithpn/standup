import 'package:breakmate/core/config/flavor_config.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/services/app_navigation_service.dart';
import 'package:breakmate/features/menu_bar/tray_manager_service.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/features/settings/settings_page.dart';
import 'package:breakmate/features/wellness/presentation/wellness_library_page.dart';
import 'package:breakmate/features/dashboard/presentation/dashboard_page.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:breakmate/core/constants/app_strings.dart';

// --- Nav item model ---

class _NavItem {
  final String label;
  final IconData icon;
  final String section;
  final bool isBottom;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.section,
    this.isBottom = false,
  });
}

// --- Intent classes ---

class _TogglePauseIntent extends Intent {
  const _TogglePauseIntent();
}

class _BreakNowIntent extends Intent {
  const _BreakNowIntent();
}

// --- Main Layout ---

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _pageIndex = 0;
  bool _isMenuOpen = false;
  late final AppNavigationService _navigationService;

  // Primary nav items (shown in the main list)
  static final List<_NavItem> _mainNavItems = [
    _NavItem(
      label: AppStrings.today,
      icon: CupertinoIcons.home,
      section: 'Today',
    ),
    _NavItem(
      label: AppStrings.navBreaks,
      icon: CupertinoIcons.timer,
      section: 'Breaks & Profiles',
    ),
    _NavItem(
      label: AppStrings.navFocusMode,
      icon: CupertinoIcons.eye,
      section: 'Intelligent Detection',
    ),
    _NavItem(
      label: AppStrings.navExercises,
      icon: CupertinoIcons.person_crop_circle,
      section: 'Exercises',
    ),
    _NavItem(
      label: AppStrings.navNotifications,
      icon: CupertinoIcons.bell,
      section: 'Notifications',
    ),
    _NavItem(
      label: AppStrings.navCompanion,
      icon: CupertinoIcons.paw,
      section: 'Companion',
    ),
    _NavItem(
      label: AppStrings.navStatistics,
      icon: CupertinoIcons.chart_bar,
      section: 'Statistics',
    ),
    _NavItem(
      label: 'Personal Goals',
      icon: CupertinoIcons.forward_fill,
      section: 'Goals',
    ),
    _NavItem(
      label: 'Wellness Library',
      icon: CupertinoIcons.book,
      section: 'Wellness Library',
    ),
    _NavItem(
      label: AppStrings.navGeneralSettings,
      icon: CupertinoIcons.settings,
      section: 'General',
    ),
  ];

  // Bottom nav items (shown at the footer of the sidebar)
  static const List<_NavItem> _bottomNavItems = [
    _NavItem(
      label: AppStrings.navDataBackup,
      icon: CupertinoIcons.folder,
      section: 'Data & Backup',
      isBottom: true,
    ),
    _NavItem(
      label: AppStrings.navSoftwareUpdate,
      icon: CupertinoIcons.arrow_down_circle,
      section: 'Updates',
      isBottom: true,
    ),
    _NavItem(
      label: AppStrings.navAbout,
      icon: CupertinoIcons.info_circle,
      section: 'About',
      isBottom: true,
    ),
  ];

  // Combined for index mapping
  List<_NavItem> get _allItems => [..._mainNavItems, ..._bottomNavItems];

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
    final index = _allItems.indexWhere((item) => item.section == section);
    if (index != -1 && index != _pageIndex && mounted) {
      setState(() => _pageIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyP):
            const _TogglePauseIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyP):
            const _TogglePauseIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyB):
            const _BreakNowIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyB):
            const _BreakNowIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _TogglePauseIntent: CallbackAction<_TogglePauseIntent>(
            onInvoke: (_) => sl<BreakController>().togglePause(),
          ),
          _BreakNowIntent: CallbackAction<_BreakNowIntent>(
            onInvoke: (_) => sl<BreakController>().takeBreakNow(),
          ),
        },
        child: Focus(
          autofocus: true,
          canRequestFocus: false,
          descendantsAreFocusable: false,
          onKeyEvent: (_, _) => KeyEventResult.ignored,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 750;

              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: isNarrow
                    ? _buildNarrowLayout(key: const ValueKey('narrow'))
                    : _buildWideLayout(key: const ValueKey('wide')),
              );
            },
          ),
        ),
      ),
    );
  }

  // --- Wide layout ---

  Widget _buildWideLayout({Key? key}) {
    return MacosWindow(
      key: key,
      backgroundColor: AppTheme.contentBackground,
      titleBar: const TitleBar(
        height: 52,
        dividerColor: Colors.transparent,
        centerTitle: true,
      ),
      sidebar: Sidebar(
        minWidth: 210,
        maxWidth: 240,
        builder: (context, scrollController) {
          return _SidebarContent(
            scrollController: scrollController,
            selectedIndex: _pageIndex,
            mainItems: _mainNavItems,
            bottomItems: _bottomNavItems,
            onItemSelected: (i) {
              setState(() => _pageIndex = i);
              _navigationService.openSection(_allItems[i].section);
            },
          );
        },
      ),
      child: Material(
        type: MaterialType.transparency,
        child: _buildMainContent(),
      ),
    );
  }

  // --- Narrow layout ---

  Widget _buildNarrowLayout({Key? key}) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        key: key,
        children: [
          _buildMainContent(),
          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: AppTheme.sidebarBackground.withValues(alpha: 0.95),
                border: Border(
                  bottom: BorderSide(color: AppTheme.separatorColor, width: 0.5),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _isMenuOpen = !_isMenuOpen),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            CupertinoIcons.bars,
                            color: AppTheme.textPrimary,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _allItems[_pageIndex].label,
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
          // Drawer overlay
          if (_isMenuOpen) ...[
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _isMenuOpen = false),
                child: Container(color: Colors.black.withValues(alpha: 0.4)),
              ),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              child: Container(
                width: 240,
                color: AppTheme.sidebarBackground,
                child: SafeArea(
                  child: _SidebarContent(
                    scrollController: null,
                    selectedIndex: _pageIndex,
                    mainItems: _mainNavItems,
                    bottomItems: _bottomNavItems,
                    onItemSelected: (i) {
                      setState(() {
                        _pageIndex = i;
                        _isMenuOpen = false;
                      });
                      _navigationService.openSection(_allItems[i].section);
                    },
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Content area ---

  Widget _buildMainContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeInOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
      transitionBuilder: (child, animation) {
        final slideAnimation =
            Tween<Offset>(
              begin: const Offset(0.0, 0.03), // premium vertical slide up
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slideAnimation, child: child),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(_pageIndex),
        child: _getPageForIndex(_pageIndex),
      ),
    );
  }

  Widget _getPageForIndex(int index) {
    switch (index) {
      case 0:
        return const DashboardPage();
      case 1:
        return const SettingsPage(section: 'Breaks & Profiles');
      case 2:
        return const SettingsPage(section: 'Intelligent Detection');
      case 3:
        return const SettingsPage(section: 'Exercises');
      case 4:
        return const SettingsPage(section: 'Notifications');
      case 5:
        return const SettingsPage(section: 'Companion');
      case 6:
        return const SettingsPage(section: 'Statistics');
      case 7:
        return const SettingsPage(section: 'Goals');
      case 8:
        return const WellnessLibraryPage();
      case 9:
        return const SettingsPage(section: 'General');
      case 10:
        return const SettingsPage(section: 'Data & Backup');
      case 11:
        return const SettingsPage(section: 'Updates');
      case 12:
        return const SettingsPage(section: 'About');
      default:
        return const DashboardPage();
    }
  }
}

// --- Sidebar Content Widget ---

class _SidebarContent extends StatelessWidget {
  final ScrollController? scrollController;
  final int selectedIndex;
  final List<_NavItem> mainItems;
  final List<_NavItem> bottomItems;
  final ValueChanged<int> onItemSelected;

  const _SidebarContent({
    this.scrollController,
    required this.selectedIndex,
    required this.mainItems,
    required this.bottomItems,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- App brand header ---
        _buildBrandHeader(),
        const SizedBox(height: 8),

        // --- Primary nav items ---
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemCount: mainItems.length,
            itemBuilder: (context, i) {
              final globalIndex = i;
              return _SidebarNavItem(
                item: mainItems[i],
                isSelected: selectedIndex == globalIndex,
                onTap: () {
                  onItemSelected(globalIndex);
                  sl<TrayManagerService>().triggerActionAnimation();
                },
              );
            },
          ),
        ),

        // --- Separator ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Divider(
            height: 1,
            thickness: 0.5,
            color: AppTheme.separatorColor,
          ),
        ),

        // --- Bottom nav items ---
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
          child: Column(
            children: bottomItems.asMap().entries.map((entry) {
              final globalIndex = mainItems.length + entry.key;
              return _SidebarNavItem(
                item: entry.value,
                isSelected: selectedIndex == globalIndex,
                onTap: () {
                  onItemSelected(globalIndex);
                  sl<TrayManagerService>().triggerActionAnimation();
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildBrandHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentColor.withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(2.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                FlavorConfig.instance.isDev
                    ? 'assets/icons/app_icon_dev.png'
                    : 'assets/icons/app_icon.jpeg',
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 14),
          // App name — two-toned
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Break',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.3,
                    fontFamily: 'Inter',
                  ),
                ),
                TextSpan(
                  text: 'Mate',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accentColor,
                    letterSpacing: -0.3,
                    fontFamily: 'Inter',
                  ),
                ),
                if (FlavorConfig.instance.isDev)
                  TextSpan(
                    text: ' DEV',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.error,
                      letterSpacing: -0.3,
                      fontFamily: 'Inter',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Sidebar Nav Item Widget ---

class _SidebarNavItem extends StatefulWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _isHovered && !isSelected
                ? AppTheme.surfaceElevated.withValues(alpha: 0.5)
                : isSelected
                ? AppTheme.surfaceElevated
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: AppTheme.border, width: 0.5)
                : Border.all(color: Colors.transparent, width: 0.5),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 3,
                height: isSelected ? 18 : 0,
                decoration: BoxDecoration(
                  color: AppTheme.accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: isSelected ? 12 : 0),
              Icon(
                widget.item.icon,
                size: 16,
                color: isSelected
                    ? AppTheme.accentColor
                    : AppTheme.textSecondary,
              ),
              const SizedBox(width: 12),
              Text(
                widget.item.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                  color: isSelected
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary,
                  letterSpacing: -0.1,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
