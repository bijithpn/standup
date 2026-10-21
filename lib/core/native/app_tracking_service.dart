import 'dart:async';
import 'package:flutter/services.dart';
import 'package:breakmate/core/utils/logger.dart';

class ActiveAppInfo {
  final String name;
  final String bundleId;
  final String executableName;

  /// The frontmost browser tab's address-bar URL, when the frontmost app is
  /// a known browser (Safari/Chrome/Edge/Brave/Opera/Vivaldi on macOS;
  /// Chrome/Edge/Firefox on Windows) and the OS-level lookup succeeded.
  /// `null` for non-browser apps or when the lookup isn't available.
  final String? url;

  ActiveAppInfo({
    required this.name,
    required this.bundleId,
    required this.executableName,
    this.url,
  });

  factory ActiveAppInfo.fromMap(Map<String, dynamic> map) {
    return ActiveAppInfo(
      name: map['name'] ?? 'Unknown',
      bundleId: map['bundleId'] ?? 'Unknown',
      executableName: map['executableName'] ?? 'Unknown',
      url: map['url'] as String?,
    );
  }

  @override
  String toString() => 'ActiveAppInfo(name: $name, bundleId: $bundleId)';
}

class AppTrackingService {
  static const _channel = MethodChannel('com.breakmate/app_tracking');
  final AppLogger _logger = AppLogger();

  Future<ActiveAppInfo?> getActiveApp() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'getActiveApp',
      );
      if (result != null) {
        return ActiveAppInfo.fromMap(result);
      }
    } on PlatformException catch (e) {
      _logger.error('Failed to get active app: ${e.message}');
    }
    return null;
  }

  Future<Uint8List?> getAppIcon({String? bundleId, String? executableName}) async {
    try {
      return await _channel.invokeMethod<Uint8List>('getAppIcon', {
        'bundleId': bundleId,
        'executableName': executableName,
      });
    } on PlatformException catch (e) {
      _logger.error('Failed to get app icon: ${e.message}');
      return null;
    }
  }
}
