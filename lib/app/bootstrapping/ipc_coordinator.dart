import 'package:breakmate/features/companion/services/companion_state_manager.dart';
import 'package:breakmate/app/bootstrapper.dart';
import 'package:breakmate/app/dependency_injection.dart';

class IpcCoordinator {
  static void coordinate() {
    sl<CompanionStateManager>().startListening();

    // Wire native IPC message channels to the Dart EventBus boundary.
    AppBootstrapper.initializeIpc();
  }
}
