import 'package:breakmate/features/companion/services/companion_state_manager.dart';
import 'package:breakmate/app/bootstrapper.dart';
import 'package:breakmate/app/dependency_injection.dart';

/// Final startup step: wires the IPC bridge and companion listeners once services exist.
class IpcCoordinator {
  static void coordinate() {
    // Must run after ServiceBootstrapper so sl<> lookups in handlers resolve.
    AppBootstrapper.initializeIpc();

    sl<CompanionStateManager>().startListening();
  }
}
