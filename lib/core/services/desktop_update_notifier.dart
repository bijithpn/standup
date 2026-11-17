import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:breakmate/core/services/feed_update_checker.dart';

/// Scheduled Windows/Linux checks; macOS is managed by Sparkle.
class DesktopUpdateNotifier {
  DesktopUpdateNotifier({
    required this.check,
    required this.notify,
    required this.readNotifiedBuild,
    required this.saveNotifiedBuild,
    this.interval = const Duration(hours: 6),
    this.startupDelay = const Duration(seconds: 10),
  });

  final Future<FeedUpdate?> Function() check;
  final Future<bool> Function(FeedUpdate) notify;
  final int Function() readNotifiedBuild;
  final Future<void> Function(int) saveNotifiedBuild;
  final Duration interval;
  final Duration startupDelay;
  Timer? _startupTimer;
  Timer? _timer;
  bool _checking = false;
  bool _disposed = false;

  void start() {
    if (_disposed || _timer != null) return;
    _startupTimer = Timer(startupDelay, () => unawaited(checkNow()));
    _timer = Timer.periodic(interval, (_) => unawaited(checkNow()));
  }

  Future<void> checkNow() async {
    if (_disposed || _checking) return;
    _checking = true;
    try {
      final update = await check();
      if (_disposed || update == null || update.build <= readNotifiedBuild()) {
        return;
      }
      if (await notify(update) && !_disposed) {
        await saveNotifiedBuild(update.build);
      }
    } catch (error) {
      // Offline or unavailable notification servers must not interrupt the app.
      debugPrint('Background update check failed: $error');
    } finally {
      _checking = false;
    }
  }

  void dispose() {
    _disposed = true;
    _startupTimer?.cancel();
    _timer?.cancel();
  }
}
