import 'package:breakmate/shared/widgets/minimal_controls.dart';
import 'dart:io';
import 'package:breakmate/core/config/flavor_config.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/services/app_navigation_service.dart';
import 'package:breakmate/features/analytics/presentation/productivity/productivity_page.dart';
import 'package:breakmate/features/menu_bar/tray_manager_service.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/shared/widgets/themed_app_icon.dart';
import 'package:breakmate/features/settings/settings_page.dart';
import 'package:breakmate/core/config/productivity_config.dart';
import 'package:breakmate/features/dashboard/presentation/dashboard_page.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:provider/provider.dart';
import 'package:breakmate/features/themes/application/theme_controller.dart';
import 'package:breakmate/core/constants/app_strings.dart';
import 'package:breakmate/features/menu_bar/controllers/menu_bar_controller.dart';

enum _NavGroup {
  today('Today'),
  insights('Insights'),
  customize('Customize'),
  system('System');

  final String label;
  const _NavGroup(this.label);
}

/// Sidebar entry mapping a label/icon to a navigation section.
class _NavItem {
  final String label;
  final IconData icon;
  final String section;
  final _NavGroup group;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.section,
    required this.group,
  });
}

class _TogglePauseIntent extends Intent {
  const _TogglePauseIntent();
}

class _BreakNowIntent extends Intent {
  const _BreakNowIntent();
}

class _QuitIntent extends Intent {
  const _QuitIntent();
}

/// Main dashboard shell: sidebar plus page switcher, with keyboard shortcuts and responsive layouts.
class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _pageIndex = 0;
  bool _isMenuOpen = false;
  late final AppNavigationService _navigationService;

  static final List<_NavItem> _allItems = [
    _NavItem(
      label: AppStrings.today,
      icon: CupertinoIcons.home,
      section: 'Today',
      group: _NavGroup.today,
    ),
    _NavItem(
      label: AppStrings.navBreaks,
      icon: CupertinoIcons.timer,
      section: 'Breaks & Profiles',
      group: _NavGroup.today,
    ),
    _NavItem(
      label: AppStrings.navSmartDetection,
      icon: CupertinoIcons.eye,
      section: 'Intelligent Detection',
      group: _NavGroup.today,
    ),
    _NavItem(
      label: 'Calendar sync',
      icon: CupertinoIcons.calendar,
      section: 'Calendar Sync',
      group: _NavGroup.today,
    ),
    if (ProductivityConfig.current.enabled)
      _NavItem(
        label: 'Productivity',
        icon: CupertinoIcons.chart_bar,
        section: 'Productivity',
        group: _NavGroup.insights,
      ),
    _NavItem(
      label: AppStrings.navStatistics,
      icon: CupertinoIcons.graph_square,
      section: 'Statistics',
      group: _NavGroup.insights,
    ),
    _NavItem(
      label: 'Personal goals',
      icon: CupertinoIcons.forward_fill,
      section: 'Goals',
      group: _NavGroup.insights,
    ),
    _NavItem(
      label: AppStrings.navCompanion,
      icon: CupertinoIcons.paw,
      section: 'Companion',
      group: _NavGroup.customize,
    ),
    _NavItem(
      label: 'Themes and styling',
      icon: CupertinoIcons.paintbrush,
      section: 'Themes',
      group: _NavGroup.customize,
    ),
    _NavItem(
      label: AppStrings.navNotifications,
      icon: CupertinoIcons.bell,
      section: 'Notifications',
      group: _NavGroup.customize,
    ),
    _NavItem(
      label: 'Privacy',
      icon: CupertinoIcons.lock_shield,
      section: 'Privacy',
      group: _NavGroup.customize,
    ),
    _NavItem(
      label: AppStrings.navGeneralSettings,
      icon: CupertinoIcons.settings,
      section: 'General',
      group: _NavGroup.customize,
    ),
    _NavItem(
      label: AppStrings.navDataBackup,
      icon: CupertinoIcons.folder,
      section: 'Data & Backup',
      group: _NavGroup.system,
    ),
    if (!Platform.isWindows)
      _NavItem(
        label: AppStrings.navSoftwareUpdate,
        icon: CupertinoIcons.arrow_down_circle,
        section: 'Updates',
        group: _NavGroup.system,
      ),
    _NavItem(
      label: AppStrings.navAbout,
      icon: CupertinoIcons.info_circle,
      section: 'About',
      group: _NavGroup.system,
    ),
  ];

  static const Map<String, String> _legacySections = {
    'Exercises': 'Breaks & Profiles',
    'Wellness Library': 'Breaks & Profiles',
  };

  String _canonicalSection(String section) =>
      _legacySections[section] ?? section;

  @override
  void initState() {
    super.initState();
    _navigationService = sl<AppNavigationService>();
    final currentSection = _canonicalSection(
      _navigationService.selectedSection.value,
    );
    final initialIndex = _allItems.indexWhere(
      (item) => item.section == currentSection,
    );
    if (initialIndex != -1) {
      _pageIndex = initialIndex;
    }
    _navigationService.selectedSection.addListener(_handleExternalNavigation);
  }

  @override
  void dispose() {
    _navigationService.selectedSection.removeListener(
      _handleExternalNavigation,
    );
    super.dispose();
  }

  // Lets other code (e.g. notifications) switch sections through AppNavigationService.
  void _handleExternalNavigation() {
    final section = _canonicalSection(_navigationService.selectedSection.value);
    final index = _allItems.indexWhere((item) => item.section == section);
    if (index != -1 && index != _pageIndex && mounted) {
      setState(() => _pageIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeController>();
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
        LogicalKeySet(
          LogicalKeyboardKey.meta,
          LogicalKeyboardKey.shiftLeft,
          LogicalKeyboardKey.keyB,
        ): const _QuitIntent(),
        LogicalKeySet(
          LogicalKeyboardKey.meta,
          LogicalKeyboardKey.shiftRight,
          LogicalKeyboardKey.keyB,
        ): const _QuitIntent(),
        LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.shiftLeft,
          LogicalKeyboardKey.keyB,
        ): const _QuitIntent(),
        LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.shiftRight,
          LogicalKeyboardKey.keyB,
        ): const _QuitIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _TogglePauseIntent: CallbackAction<_TogglePauseIntent>(
            onInvoke: (_) => sl<BreakController>().togglePause(),
          ),
          _BreakNowIntent: CallbackAction<_BreakNowIntent>(
            onInvoke: (_) => sl<BreakController>().takeBreakNow(),
          ),
          _QuitIntent: CallbackAction<_QuitIntent>(
            onInvoke: (_) => sl<MenuBarController>().handleAction('quit'),
          ),
        },
        child: Focus(
          autofocus: false,
          canRequestFocus: false,
          descendantsAreFocusable: true,
          onKeyEvent: null,
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

  Widget _buildWideLayout({Key? key}) {
    return MacosWindow(
      key: key,
      backgroundColor: AppTheme.contentBackground,
      sidebar: Sidebar(
        minWidth: 240,
        maxWidth: 240,
        builder: (context, scrollController) {
          return _SidebarContent(
            scrollController: scrollController,
            selectedIndex: _pageIndex,
            onItemSelected: (i) {
              setState(() => _pageIndex = i);
              _navigationService.openSection(_allItems[i].section);
            },
          );
        },
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: AppTheme.separatorColor)),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: _buildMainContent(),
        ),
      ),
    );
  }

  Widget _buildNarrowLayout({Key? key}) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        key: key,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 52),
            child: _buildMainContent(),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: AppTheme.sidebarBackground.withValues(alpha: 0.95),
                border: Border(
                  bottom: BorderSide(
                    color: AppTheme.separatorColor,
                    width: 0.5,
                  ),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      TapTarget(
                        semanticLabel: 'Toggle menu',
                        onTap: () => setState(() => _isMenuOpen = !_isMenuOpen),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.textPrimary.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
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
                          fontWeight: FontWeight.w500,
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

  Widget _buildMainContent() {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 120),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: KeyedSubtree(
        key: ValueKey(_pageIndex),
        child: _getPageForIndex(_pageIndex),
      ),
    );
  }

  Widget _getPageForIndex(int index) {
    if (index < 0 || index >= _allItems.length) {
      return const DashboardPage();
    }
    final section = _allItems[index].section;
    switch (section) {
      case 'Today':
        return const DashboardPage();
      case 'Breaks & Profiles':
        return const SettingsPage(section: 'Breaks & Profiles');
      case 'Intelligent Detection':
        return const SettingsPage(section: 'Intelligent Detection');
      case 'Calendar Sync':
        return const SettingsPage(section: 'Calendar Sync');
      case 'Notifications':
        return const SettingsPage(section: 'Notifications');
      case 'Companion':
        return const SettingsPage(section: 'Companion');
      case 'Productivity':
        return const ProductivityPage();
      case 'Statistics':
        return const SettingsPage(section: 'Statistics');
      case 'Goals':
        return const SettingsPage(section: 'Goals');
      case 'Themes':
      case 'Themes & Styling':
        return const SettingsPage(section: 'Themes');
      case 'Privacy':
        return const SettingsPage(section: 'Privacy');
      case 'General':
        return const SettingsPage(section: 'General');
      case 'Data & Backup':
        return const SettingsPage(section: 'Data & Backup');
      case 'Updates':
        return const SettingsPage(section: 'Updates');
      case 'About':
        return const SettingsPage(section: 'About');
      default:
        return const DashboardPage();
    }
  }
}

class _SidebarContent extends StatelessWidget {
  final ScrollController? scrollController;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const _SidebarContent({
    this.scrollController,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final items = _MainLayoutState._allItems;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 44, 24, 8),
          child: Row(
            children: [
              Semantics(
                label: 'BreakMate app icon',
                child: ThemedAppIcon.badge(
                  size: 28,
                  iconSize: 20,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  showDevBadge: false,
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Flexible(
                child: Text(
                  'BreakMate',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              if (FlavorConfig.instance.isDev) ...[
                const SizedBox(width: AppTheme.space8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.borderSubtle),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'DEV',
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textMuted,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i == 0 || items[i].group != items[i - 1].group)
                  Padding(
                    padding: EdgeInsets.fromLTRB(12, i == 0 ? 16 : 24, 12, 4),
                    child: Text(
                      items[i].group.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.textMuted,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                _SidebarNavItem(
                  item: items[i],
                  isSelected: selectedIndex == i,
                  onTap: () {
                    onItemSelected(i);
                    sl<TrayManagerService>().triggerActionAnimation();
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

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
    final color = isSelected ? AppTheme.textPrimary : AppTheme.textSecondary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: widget.item.label,
        waitDuration: const Duration(milliseconds: 600),
        child: TapTarget(
          onTap: widget.onTap,
          selected: isSelected,
          semanticLabel: widget.item.label,
          child: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                constraints: const BoxConstraints(minHeight: 32),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space12,
                  vertical: AppTheme.space8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.surfaceElevated
                      : _isHovered
                      ? AppTheme.surfaceElevated.withValues(alpha: 0.5)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(widget.item.icon, size: 16, color: color),
                    const SizedBox(width: AppTheme.space12),
                    Expanded(
                      child: Text(
                        widget.item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w500
                              : FontWeight.w400,
                          color: color,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Positioned(
                  left: 0,
                  top: AppTheme.space8,
                  bottom: AppTheme.space8,
                  width: 2,
                  child: ColoredBox(color: AppTheme.accentColor),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
