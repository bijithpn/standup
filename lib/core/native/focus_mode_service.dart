import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class FocusModeService {
  final _channel = const EventChannel('com.standup/focus_mode');

  Stream<bool> get isFocusModeActiveStream {
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      return const Stream<bool>.empty();
    }
    return _channel.receiveBroadcastStream().map((event) {
      final isFocus = event as bool;
      debugPrint('Focus Mode / DND state changed: $isFocus');
      return isFocus;
    }).handleError((error) {
      debugPrint('Focus mode detection fallback hit: $error');
      return false;
    });
  }
}
