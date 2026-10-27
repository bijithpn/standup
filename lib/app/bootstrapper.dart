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
      event.when(
        timerStateChanged:
            (
              stateName,
              countdownSeconds,
              workElapsedSeconds,
              targetEndTime,
              totalWorkTodaySeconds,
            ) {
              final endTime = targetEndTime != null
                  ? DateTime.fromMillisecondsSinceEpoch(targetEndTime)
                  : null;

              TimerStateEvent? timerState;
              switch (stateName) {
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
                    countdownSeconds: countdownSeconds,
                    workElapsedSeconds: workElapsedSeconds,
                    targetEndTime: endTime,
                    totalWorkTodaySeconds: totalWorkTodaySeconds,
                  ),
                );
              }
            },
        breakStarted: (isLongBreak, durationSeconds, title) {
          eventBus.emit(
            BreakStartedEvent(
              isLongBreak: isLongBreak,
              durationSeconds: durationSeconds,
              title: title,
            ),
          );
        },
        breakEnded: (skipped) {
          eventBus.emit(BreakEndedEvent(skipped: skipped));
        },
        meetingDetected: (isActive, bundleId) {
          eventBus.emit(
            MeetingDetectedEvent(isActive: isActive, bundleId: bundleId),
          );
        },
        trayAction: (action) {
          if (action == 'start') {
            timerEngine.startTimers();
          } else if (action == 'pause') {
            timerEngine.pauseTimers(isManual: true);
          } else if (action == 'reset') {
            timerEngine.resetTimers();
          }
        },
        companionClose: () {
          sl<CompanionOverlayController>().toggleCompanion(false);
        },
        companionPositionChanged: (x, y) {
          eventBus.emit(CompanionPositionChangedEvent(x: x, y: y));
        },
        companionStateChanged: (state) {
          eventBus.emit(
            CompanionStateChangedEvent(
              state: CompanionState.values.firstWhere(
                (s) => s.name == state,
                orElse: () => CompanionState.idle,
              ),
            ),
          );
        },
        companionInteraction: (interactionType, metadata) {
          eventBus.emit(
            CompanionInteractionEvent(
              interactionType: interactionType,
              metadata: metadata,
            ),
          );
        },
        unknown: (eventName, payload) {
          // Do nothing for unknown events
        },
      );
    });
  }
}
