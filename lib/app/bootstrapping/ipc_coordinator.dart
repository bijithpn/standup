import 'package:breakmate/features/companion/services/companion_state_manager.dart';
import 'package:breakmate/app/bootstrapper.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:breakmate/features/menu_bar/tray_manager_service.dart';
import 'package:breakmate/features/menu_bar/controllers/menu_bar_controller.dart';

/// Centralizes runtime coordination between services, event subscriptions, 
/// and native IPC wiring after initialization is complete.
class IpcCoordinator {
  static void coordinate() {
    // Wire native IPC message channels to the Dart EventBus boundary.
    AppBootstrapper.initializeIpc();

    // Establish service-to-service dependencies that cannot be resolved during registration.
    final trayManager = sl<TrayManagerService>();
    trayManager.setDependencies(sl<TimerEngine>(), sl<BreakController>());
    trayManager.setMenuBarController(sl<MenuBarController>());

    sl<MenuBarController>().setDependencies(sl());
    sl<CompanionStateManager>().startListening();
  }
}
