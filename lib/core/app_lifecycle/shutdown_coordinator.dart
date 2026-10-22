import 'package:breakmate/core/services/simple_prefs.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/services/timer_orchestrator.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/analytics/app_usage_tracker.dart';
import 'package:breakmate/features/analytics/weekly_digest_service.dart';
import 'package:breakmate/features/analytics/focus_insight_service.dart';
import 'package:breakmate/features/analytics/focus_streak_service.dart';
import 'package:breakmate/core/services/background_polling_service.dart';
import 'package:breakmate/core/services/overlay_window_service.dart';
import 'package:breakmate/features/menu_bar/tray_manager_service.dart';
import 'package:breakmate/core/utils/logger.dart';

class ShutdownCoordinator {
  ShutdownCoordinator._();
  static final ShutdownCoordinator instance = ShutdownCoordinator._();

  final AppLogger _logger = AppLogger();

  Future<void> shutdown() async {
    _logger.info('Initiating graceful shutdown...');

    // Preferences are written a moment after they change; make sure the last
    // ones are on disk before the process goes.
    SimplePrefs.instance.flush();

    try {
      if (sl.isRegistered<TimerOrchestrator>()) {
        final orchestrator = sl<TimerOrchestrator>();
        orchestrator.shutdown();
        _logger.info('TimerOrchestrator saved state, paused and shut down.');
      }
    } catch (e) {
      _logger.error('Failed to shutdown TimerOrchestrator: $e');
    }

    try {
      if (sl.isRegistered<StatsService>()) {
        sl<StatsService>().flush();
        _logger.info('StatsService flushed.');
      }
    } catch (e) {
      _logger.error('Failed to flush StatsService: $e');
    }

    try {
      if (sl.isRegistered<AppUsageTracker>()) {
        sl<AppUsageTracker>().stop();
        _logger.info('AppUsageTracker stopped and flushed.');
      }
    } catch (e) {
      _logger.error('Failed to stop AppUsageTracker: $e');
    }

    try {
      if (sl.isRegistered<WeeklyDigestService>()) {
        sl<WeeklyDigestService>().stop();
        _logger.info('WeeklyDigestService stopped.');
      }
    } catch (e) {
      _logger.error('Failed to stop WeeklyDigestService: $e');
    }

    try {
      if (sl.isRegistered<FocusInsightService>()) {
        sl<FocusInsightService>().stop();
        _logger.info('FocusInsightService stopped.');
      }
    } catch (e) {
      _logger.error('Failed to stop FocusInsightService: $e');
    }

    try {
      if (sl.isRegistered<FocusStreakService>()) {
        sl<FocusStreakService>().stop();
        _logger.info('FocusStreakService stopped.');
      }
    } catch (e) {
      _logger.error('Failed to stop FocusStreakService: $e');
    }

    try {
      if (sl.isRegistered<BackgroundPollingService>()) {
        sl<BackgroundPollingService>().stop();
        _logger.info('BackgroundPollingService stopped.');
      }
    } catch (e) {
      _logger.error('Failed to stop BackgroundPollingService: $e');
    }

    try {
      if (sl.isRegistered<OverlayWindowService>()) {
        sl<OverlayWindowService>().hideOverlay();
        _logger.info('Overlays hidden.');
      }
    } catch (e) {
      _logger.error('Failed to hide overlays: $e');
    }

    try {
      if (sl.isRegistered<TrayManagerService>()) {
        final tray = sl<TrayManagerService>();
        tray.dispose();
        _logger.info('Tray resources disposed.');
      }
    } catch (e) {
      _logger.error('Failed to dispose TrayManagerService: $e');
    }

    _logger.info('Graceful shutdown completed.');
  }
}
