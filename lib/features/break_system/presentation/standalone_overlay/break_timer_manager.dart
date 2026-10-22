import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:breakmate/core/native/native_bridge.dart';

mixin BreakTimerManager<T extends StatefulWidget> on State<T> {
  static const MethodChannel bridgeChannel = MethodChannel(
    'com.breakmate.desktop/bridge',
  );

  int durationSeconds = 300;
  int remainingSeconds = 300;
  DateTime? targetEndTime;
  Timer? localTimer;
  late final ValueNotifier<int> remainingSecondsNotifier = ValueNotifier<int>(
    remainingSeconds,
  );

  bool isDismissing = false;

  void startLocalTimer(VoidCallback onComplete) {
    localTimer?.cancel();
    localTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (targetEndTime != null) {
        final newRemaining = targetEndTime!
            .difference(DateTime.now())
            .inSeconds
            .clamp(0, durationSeconds);

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

  void completeBreak(
    bool isInternalPreview,
    String overlayType,
    AnimationController fadeController,
  ) {
    if (isDismissing) return;
    isDismissing = true;

    bool callbackTriggered = false;
    void triggerDismiss() {
      if (callbackTriggered) return;
      callbackTriggered = true;
      if (isInternalPreview) {
        bridgeChannel.invokeMethod('hideOverlay', {'restoreMainWindow': true});
      } else if (overlayType == 'preBreakWarning' ||
          overlayType == 'quickReminder') {
        bridgeChannel.invokeMethod('hideOverlay', {'restoreMainWindow': false});
      } else {
        bridgeChannel.invokeMethod('completeBreak');
      }
    }

    Timer(const Duration(milliseconds: 800), triggerDismiss);

    fadeController.reverse().then((_) {
      triggerDismiss();
    });
  }

  void skipBreak(
    bool isInternalPreview,
    String overlayType,
    AnimationController fadeController,
  ) {
    if (isDismissing) return;
    isDismissing = true;

    bool callbackTriggered = false;
    void triggerDismiss() {
      if (callbackTriggered) return;
      callbackTriggered = true;
      if (isInternalPreview) {
        bridgeChannel.invokeMethod('hideOverlay', {'restoreMainWindow': true});
      } else if (overlayType == 'preBreakWarning' ||
          overlayType == 'quickReminder') {
        bridgeChannel.invokeMethod('hideOverlay', {'restoreMainWindow': false});
      } else {
        NativeBridge.skipBreak();
      }
    }

    Timer(const Duration(milliseconds: 800), triggerDismiss);

    fadeController.reverse().then((_) {
      triggerDismiss();
    });
  }

  @override
  void dispose() {
    localTimer?.cancel();
    remainingSecondsNotifier.dispose();
    super.dispose();
  }
}
