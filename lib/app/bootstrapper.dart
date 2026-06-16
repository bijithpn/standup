import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/ipc/ipc_bridge.dart';
import 'package:breakmate/core/ipc/ipc_events.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/features/companion/controllers/companion_overlay_controller.dart';
import 'package:breakmate/app/dependency_injection.dart';

class AppBootstrapper {
  static void initializeIpc() {
    final ipc = IpcBridge.instance;
    final eventBus = sl<EventBus>();
    final timerEngine = sl<TimerEngine>();

    ipc.setTypedEventHandler((event) {
      if (event is TimerStateChangedIpcEvent) {
        final targetEndTime = event.targetEndTime != null
            ? DateTime.fromMillisecondsSinceEpoch(event.targetEndTime!)
            : null;

        TimerStateEvent? timerState;
        switch (event.stateName) {
          case 'running':
            timerState = TimerStateEvent.running;
            break;
          case 'breakActive':
            timerState = TimerStateEvent.breakActive;
            break;
          case 'paused':
            timerState = TimerStateEvent.paused;
            break;
          case 'idle':
            timerState = TimerStateEvent.idle;
            break;
        }

        if (timerState != null) {
          eventBus.emit(
            TimerStateChangedEvent(
              state: timerState,
              countdownSeconds: event.countdownSeconds,
              workElapsedSeconds: event.workElapsedSeconds,
              targetEndTime: targetEndTime,
              totalWorkTodaySeconds: event.totalWorkTodaySeconds,
            ),
          );
        }
      } else if (event is BreakStartedIpcEvent) {
        eventBus.emit(
          BreakStartedEvent(
            isLongBreak: event.isLongBreak,
            durationSeconds: event.durationSeconds,
            title: event.title,
          ),
        );
      } else if (event is BreakEndedIpcEvent) {
        eventBus.emit(BreakEndedEvent(skipped: event.skipped));
      } else if (event is MeetingDetectedIpcEvent) {
        eventBus.emit(
          MeetingDetectedEvent(
            isActive: event.isActive,
            bundleId: event.bundleId,
          ),
        );
      } else if (event is FocusModeIpcEvent) {
        eventBus.emit(FocusModeEvent(isActive: event.isActive));
      } else if (event is TrayActionIpcEvent) {
        if (event.action == 'start') {
          timerEngine.startTimers();
        } else if (event.action == 'pause') {
          timerEngine.pauseTimers(isManual: true);
        } else if (event.action == 'reset') {
          timerEngine.resetTimers();
        }
      } else if (event is CompanionCloseIpcEvent) {
        sl<CompanionOverlayController>().toggleCompanion(false);
      } else if (event is CompanionPositionChangedIpcEvent) {
        eventBus.emit(CompanionPositionChangedEvent(x: event.x, y: event.y));
      } else if (event is CompanionStateChangedIpcEvent) {
        eventBus.emit(
          CompanionStateChangedEvent(
            state: CompanionState.values.firstWhere(
              (s) => s.name == event.state,
              orElse: () => CompanionState.idle,
            ),
          ),
        );
      } else if (event is CompanionInteractionIpcEvent) {
        eventBus.emit(
          CompanionInteractionEvent(
            interactionType: event.interactionType,
            metadata: event.metadata,
          ),
        );
      }
    });
  }
}
