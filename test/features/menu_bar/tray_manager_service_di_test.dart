import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:breakmate/features/menu_bar/controllers/menu_bar_controller.dart';
import 'package:breakmate/features/menu_bar/tray_manager_service.dart';

class FakeTimerEngine extends Fake implements TimerEngine {
  @override
  void addListener(void Function() listener) {}
  @override
  void removeListener(void Function() listener) {}
  @override
  TimerState get state => TimerState.running;
  @override
  bool get systemSleepPaused => false;
}

class FakeBreakController extends Fake implements BreakController {
  @override
  void addListener(void Function() listener) {}
  @override
  void removeListener(void Function() listener) {}
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });
  test('MenuBarController accepts breakController via constructor', () {
    final breakController = FakeBreakController();
    final controller = MenuBarController(
      eventBus: EventBus.instance,
      breakController: breakController,
    );
    expect(controller, isNotNull);
  });

  test('TrayManagerService accepts dependencies via constructor injection', () {
    final timerEngine = FakeTimerEngine();
    final breakController = FakeBreakController();
    final menuBarController = MenuBarController();

    final trayManager = TrayManagerService(
      timerEngine: timerEngine,
      breakController: breakController,
      menuBarController: menuBarController,
    );
    expect(trayManager, isNotNull);
  });
}
