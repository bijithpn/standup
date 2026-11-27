import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:breakmate/core/native/native_bridge.dart';

/// Countdown and dismissal logic for the overlay state: ticks against a wall-clock end time and reports completion/skip to native.
mixin BreakTimerManager<T extends StatefulWidget> on State<T> {
  static const MethodChannel bridgeChannel = MethodChannel(
    'com.breakmate.desktop/bridge',
  );

  int durationSeconds = 60;
  int remainingSeconds = 60;
  DateTime? targetEndTime;
  Timer? localTimer;
  late final ValueNotifier<int> remainingSecondsNotifier = ValueNotifier<int>(
    remainingSeconds,
  );

  bool isDismissing = false;

  static const Duration completionHold = Duration(milliseconds: 400);

  final ValueNotifier<bool> completing = ValueNotifier<bool>(false);

  // Ceil, not Duration.inSeconds: a 1s warning (0.99s left on arrival) must read 1, or it starts at 0 and never "completes".
  int secondsUntil(DateTime end) =>
      (end.difference(DateTime.now()).inMilliseconds / 1000).ceil().clamp(
        0,
        durationSeconds,
      );

  // Derived from targetEndTime each second (not decremented) so it stays accurate across missed ticks.
  void startLocalTimer(VoidCallback onComplete) {
    localTimer?.cancel();
    localTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (targetEndTime != null) {
        final newRemaining = secondsUntil(targetEndTime!);

        if (newRemaining != remainingSeconds) {
          if (newRemaining == 0 && remainingSeconds > 0) {
            onComplete();
          }
          remainingSeconds = newRemaining;
          remainingSecondsNotifier.value = newRemaining;
        }
      }
    });
  }

  void cancelTimer() {
    localTimer?.cancel();
    localTimer = null;
  }

  /// Plays the completion animation, then tells native; the fallback timer guarantees dismissal if the fade never finishes.
  void completeBreak(
    bool isInternalPreview,
    String overlayType,
    AnimationController fadeController,
  ) {
    if (isDismissing) return;
    isDismissing = true;
    completing.value = true;

    bool callbackTriggered = false;
    void triggerDismiss() {
      if (callbackTriggered) return;
      callbackTriggered = true;
      if (isInternalPreview) {
        bridgeChannel.invokeMethod('hideOverlay', {'restoreMainWindow': true});
      } else if (overlayType == 'quickReminder') {
        bridgeChannel.invokeMethod('hideOverlay', {'restoreMainWindow': false});
      } else {
        bridgeChannel.invokeMethod('completeBreak');
      }
    }

    Timer(completionHold + const Duration(milliseconds: 800), triggerDismiss);

    Timer(completionHold, () {
      if (!mounted) return;
      fadeController.reverse().then((_) => triggerDismiss());
    });
  }

  /// Dismisses early; previews and reminders only hide the window, real breaks call native skip so the main app records it.
  void skipBreak(
    bool isInternalPreview,
    String overlayType,
    AnimationController fadeController, {
    String? reason,
  }) {
    if (isDismissing) return;
    isDismissing = true;

    bool callbackTriggered = false;
    void triggerDismiss() {
      if (callbackTriggered) return;
      callbackTriggered = true;
      if (isInternalPreview) {
        bridgeChannel.invokeMethod('hideOverlay', {'restoreMainWindow': true});
      } else if (overlayType == 'quickReminder') {
        bridgeChannel.invokeMethod('hideOverlay', {'restoreMainWindow': false});
      } else {
        if (overlayType == 'preBreakWarning') {
          bridgeChannel.invokeMethod('hideOverlay', {
            'restoreMainWindow': false,
          });
        }
        if (reason != null) {
          bridgeChannel.invokeMethod('skipBreak', {'reason': reason});
        } else {
          NativeBridge.skipBreak();
        }
      }
    }

    Timer(const Duration(milliseconds: 800), triggerDismiss);

    fadeController.reverse().then((_) {
      triggerDismiss();
    });
  }

  /// Delays the upcoming break: hides the warning and has the main app pause timers for a few minutes.
  void snoozeBreak(AnimationController fadeController) {
    if (isDismissing) return;
    isDismissing = true;
    fadeController.reverse().whenComplete(() {
      bridgeChannel.invokeMethod('snoozeBreak');
    });
  }

  /// Hides the warning only; the break still starts on schedule.
  void closeWarning(AnimationController fadeController) {
    if (isDismissing) return;
    isDismissing = true;
    fadeController.reverse().whenComplete(() {
      bridgeChannel.invokeMethod('hideOverlay', {'restoreMainWindow': false});
    });
  }

  void startDragging() => bridgeChannel.invokeMethod('startDragging');

  @override
  void dispose() {
    localTimer?.cancel();
    remainingSecondsNotifier.dispose();
    completing.dispose();
    super.dispose();
  }
}
