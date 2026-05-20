import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:standup/app/dependency_injection.dart';
import 'package:standup/core/services/app_navigation_service.dart';
import 'package:standup/shared/theme/app_theme.dart';
import 'package:standup/features/settings/settings_page.dart';

// ─── Nav item model ────────────────────────────────────────────────────────

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

// ─── Main Layout ──────────────────────────────────────────────────────────

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
  static const List<_NavItem> _mainNavItems = [
    _NavItem(label: 'General', icon: CupertinoIcons.settings, section: 'General'),
    _NavItem(label: 'Breaks', icon: CupertinoIcons.timer, section: 'Breaks & Profiles'),
    _NavItem(label: 'Focus mode', icon: CupertinoIcons.eye, section: 'Intelligent Detection'),
    _NavItem(label: 'Flash Reminder', icon: CupertinoIcons.bolt, section: 'Flash Reminder'),
    _NavItem(label: 'Exercises', icon: CupertinoIcons.person_crop_circle, section: 'Exercises'),
    _NavItem(label: 'Clock Out', icon: CupertinoIcons.moon, section: 'Clock Out'),
    _NavItem(label: 'Statistics', icon: CupertinoIcons.chart_bar, section: 'Statistics'),
  ];

  // Bottom nav items (shown at the footer of the sidebar)
  static const List<_NavItem> _bottomNavItems = [
    _NavItem(label: 'Manage License', icon: CupertinoIcons.checkmark_circle, section: 'License', isBottom: true),
    _NavItem(label: 'About', icon: CupertinoIcons.info_circle, section: 'About', isBottom: true),
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
    _navigationService.selectedSection.removeListener(_handleExternalNavigation);
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 750;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          child: isNarrow
              ? _buildNarrowLayout(key: const ValueKey('narrow'))
              : _buildWideLayout(key: const ValueKey('wide')),
        );
      },
    );
  }

  // ─── Wide layout ──────────────────────────────────────────────────────────

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
            selectedIndex: _pageIndex,
            mainItems: _mainNavItems,
            bottomItems: _bottomNavItems,
            onItemSelected: (i) => setState(() => _pageIndex = i),
          );
        },
      ),
      child: _buildMainContent(),
    );
  }

  // ─── Narrow layout ────────────────────────────────────────────────────────

  Widget _buildNarrowLayout({Key? key}) {
    return Stack(
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
              border: const Border(
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
                  selectedIndex: _pageIndex,
                  mainItems: _mainNavItems,
                  bottomItems: _bottomNavItems,
                  onItemSelected: (i) {
                    setState(() {
                      _pageIndex = i;
                      _isMenuOpen = false;
                    });
                  },
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ─── Content area ─────────────────────────────────────────────────────────

  Widget _buildMainContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: child,
      ),
      child: IndexedStack(
        key: ValueKey(_pageIndex),
        index: _pageIndex,
        children: const [
          SettingsPage(section: 'General'),
          SettingsPage(section: 'Breaks & Profiles'),
          SettingsPage(section: 'Intelligent Detection'),
          SettingsPage(section: 'Flash Reminder'),
          SettingsPage(section: 'Exercises'),
          SettingsPage(section: 'Clock Out'),
          SettingsPage(section: 'Statistics'),
          // Bottom nav
          SettingsPage(section: 'License'),
          SettingsPage(section: 'About'),
        ],
      ),
    );
  }
}

// ─── Sidebar Content Widget ────────────────────────────────────────────────

class _SidebarContent extends StatelessWidget {
  final int selectedIndex;
  final List<_NavItem> mainItems;
  final List<_NavItem> bottomItems;
  final ValueChanged<int> onItemSelected;

  const _SidebarContent({
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
        // ── App brand header ──────────────────────────────────
        _buildBrandHeader(),
        const SizedBox(height: 8),

        // ── Primary nav items ─────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemCount: mainItems.length,
            itemBuilder: (context, i) {
              final globalIndex = i;
              return _SidebarNavItem(
                item: mainItems[i],
                isSelected: selectedIndex == globalIndex,
                onTap: () => onItemSelected(globalIndex),
              );
            },
          ),
        ),

        // ── Separator ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Divider(
            height: 1,
            thickness: 0.5,
            color: AppTheme.separatorColor,
          ),
        ),
        const SizedBox(height: 4),

        // ── Bottom nav items ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            children: bottomItems.asMap().entries.map((entry) {
              final globalIndex = mainItems.length + entry.key;
              return _SidebarNavItem(
                item: entry.value,
                isSelected: selectedIndex == globalIndex,
                onTap: () => onItemSelected(globalIndex),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
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
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                CupertinoIcons.infinite,
                color: Color(0xFF1C1C1E),
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 14),
          // App name — two-toned
          RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'Break',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                    fontFamily: 'Satoshi',
                  ),
                ),
                TextSpan(
                  text: 'Mate',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accentColor,
                    letterSpacing: -0.3,
                    fontFamily: 'Satoshi',
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

// ─── Sidebar Nav Item Widget ───────────────────────────────────────────────

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
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFFF453A).withValues(alpha: 0.12)
                : _isHovered
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                widget.item.icon,
                size: 16,
                color: isSelected
                    ? const Color(0xFFFF453A)
                    : AppTheme.textSecondary,
              ),
              const SizedBox(width: 10),
              Text(
                widget.item.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary,
                  letterSpacing: -0.1,
                  fontFamily: 'Satoshi',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
