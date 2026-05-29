import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class MeetingDetectionService {
  final _channel = const EventChannel('com.breakmate/meeting_detection');

  Stream<bool> get isMeetingActiveStream {
    if (defaultTargetPlatform != TargetPlatform.macOS &&
        defaultTargetPlatform != TargetPlatform.windows) {
      return const Stream<bool>.empty();
    }
    return _channel
        .receiveBroadcastStream()
        .map((event) {
          final data = Map<String, dynamic>.from(event);
          final isMeeting = data['isMeetingAppFrontmost'] as bool? ?? false;
          debugPrint(
            'Frontmost app changed: ${data['bundleId']} (Meeting: $isMeeting)',
          );
          return isMeeting;
        })
        .handleError((error) {
          debugPrint('Error receiving meeting stream: $error');
          // Defensive programming: never crash, fallback to false
          return false;
        });
  }
}
