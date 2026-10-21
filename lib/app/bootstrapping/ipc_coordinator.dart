import 'package:breakmate/features/companion/services/companion_state_manager.dart';
import 'package:breakmate/app/bootstrapper.dart';
import 'package:breakmate/app/dependency_injection.dart';

/// Centralizes runtime coordination between services, event subscriptions, 
/// and native IPC wiring after initialization is complete.
class IpcCoordinator {
  static void coordinate() {
    // Wire native IPC message channels to the Dart EventBus boundary.
    AppBootstrapper.initializeIpc();

    // Service-to-service dependencies for TrayManager and MenuBarController
    // are now constructor-injected in dependency_injection.dart.
    sl<CompanionStateManager>().startListening();
  }
}
