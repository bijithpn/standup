import 'dart:async';

import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';

import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/constants/app_strings.dart';
import 'package:breakmate/core/services/calendar_service.dart';
import 'package:breakmate/core/utils/toast.dart';
import 'package:breakmate/features/dashboard/presentation/widgets/dashboard_header.dart';
import 'package:breakmate/features/dashboard/presentation/widgets/timer_section.dart';
import 'package:breakmate/features/dashboard/presentation/widgets/action_grid.dart';
import 'package:breakmate/features/dashboard/presentation/widgets/calendar_section.dart';
import 'package:breakmate/features/dashboard/presentation/widgets/daily_summary_section.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with WidgetsBindingObserver {
  List<CalendarEvent>? _calendarEvents;
  bool _calendarLoading = false;
  bool _calendarPermissionGranted = false;
  bool _calendarPermissionDenied = false;
  bool _isRequestingPermission = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCalendarEvents();
    // Refresh calendar events every 2 minutes
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      _loadCalendarEvents();
    });

    // Listen for setting changes to refresh calendar data if enabled
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        sl<SettingsRepository>().addListener(_handleSettingsChange);
      }
    });
  }

  void _handleSettingsChange() {
    if (mounted) {
      _loadCalendarEvents();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadCalendarEvents();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    sl<SettingsRepository>().removeListener(_handleSettingsChange);
    super.dispose();
  }

  Future<void> _loadCalendarEvents() async {
    final settings = sl<SettingsRepository>().currentSettings;
    if (!settings.calendarEnabled) {
      setState(() {
        _calendarEvents = null;
        _calendarLoading = false;
      });
      return;
    }

    final calendarService = sl<CalendarService>();
    if (mounted) {
      setState(() => _calendarLoading = true);
    }

    try {
      final hasPermission = await calendarService.checkPermissions();
      if (!hasPermission) {
        if (mounted) {
          setState(() {
            _calendarPermissionGranted = false;
            _calendarLoading = false;
          });
        }
        return;
      }

      _calendarPermissionGranted = true;
      _calendarPermissionDenied = false; // Reset if confirmed

      // Query events for the entire current day (from start of today to end of today)
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final events = await calendarService.getEvents(startOfToday, endOfToday);
      if (mounted) {
        setState(() {
          _calendarEvents = events;
          _calendarLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _calendarLoading = false);
      }
    }
  }

  Future<void> _requestCalendarAccess() async {
    if (_isRequestingPermission) return;

    setState(() => _isRequestingPermission = true);

    try {
      final calendarService = sl<CalendarService>();
      final granted = await calendarService.requestPermissions();

      if (mounted) {
        if (granted) {
          setState(() {
            _calendarPermissionGranted = true;
            _calendarPermissionDenied = false;
          });
          Toast.showSuccess(context, 'Calendar access granted!');
          await _loadCalendarEvents();
        } else {
          setState(() {
            _calendarPermissionGranted = false;
            _calendarPermissionDenied = true;
          });
          Toast.showError(
            context,
            'Calendar access denied. Please enable it in System Settings.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Toast.showError(context, 'An unexpected error occurred.');
      }
    } finally {
      if (mounted) {
        setState(() => _isRequestingPermission = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 600;
        final padding = isSmall ? 20.0 : 40.0;

        Widget buildContent(ScrollController? scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.all(padding),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Consumer<SettingsRepository>(
                  builder: (context, settingsRepo, _) {
                    final calendarEnabled =
                        settingsRepo.currentSettings.calendarEnabled;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        const DashboardHeader(),
                        const SizedBox(height: 40),
                        TimerSection(calendarEvents: _calendarEvents),
                        const SizedBox(height: 40),
                        const ActionGrid(),
                        if (calendarEnabled) ...[
                          const SizedBox(height: 40),
                          CalendarSection(
                            calendarEvents: _calendarEvents,
                            loading: _calendarLoading,
                            permissionGranted: _calendarPermissionGranted,
                            permissionDenied: _calendarPermissionDenied,
                            isRequestingPermission: _isRequestingPermission,
                            onLoadEvents: _loadCalendarEvents,
                            onRequestAccess: _requestCalendarAccess,
                          ),
                        ],
                        const SizedBox(height: 40),
                        const DailySummarySection(),
                        const SizedBox(height: 20),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        }

        if (isSmall) {
          return Scaffold(
            backgroundColor: AppTheme.surface,
            body: SafeArea(child: buildContent(null)),
          );
        }

        return MacosScaffold(
          backgroundColor: AppTheme.surface,
          toolBar: const ToolBar(
            title: Text(
              AppStrings.today,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            titleWidth: 260,
            actions: [],
          ),
          children: [
            ContentArea(
              builder: (context, scrollController) =>
                  buildContent(scrollController),
            ),
          ],
        );
      },
    );
  }
}
