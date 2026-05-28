import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
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

    try {
      // 1. Save timer state and stop timers
      if (sl.isRegistered<TimerEngine>()) {
        final timerEngine = sl<TimerEngine>();
        timerEngine.pauseTimers(isManual: true);
        timerEngine.saveState();
        _logger.info('TimerEngine state saved and paused.');
      }
    } catch (e) {
      _logger.error('Failed to shutdown TimerEngine: $e');
    }

    try {
      // 2. Flush stats
      if (sl.isRegistered<StatsService>()) {
        sl<StatsService>().flush();
        _logger.info('StatsService flushed.');
      }
    } catch (e) {
      _logger.error('Failed to flush StatsService: $e');
    }

    try {
      // 3. Stop background polling
      if (sl.isRegistered<BackgroundPollingService>()) {
        sl<BackgroundPollingService>().stop();
        _logger.info('BackgroundPollingService stopped.');
      }
    } catch (e) {
      _logger.error('Failed to stop BackgroundPollingService: $e');
    }

    try {
      // 4. Hide overlays
      if (sl.isRegistered<OverlayWindowService>()) {
        sl<OverlayWindowService>().hideOverlay();
        _logger.info('Overlays hidden.');
      }
    } catch (e) {
      _logger.error('Failed to hide overlays: $e');
    }

    try {
      // 5. Dispose tray resources
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
