import 'dart:async';
import 'package:flutter/services.dart';
import 'package:breakmate/core/utils/logger.dart';

class ActiveAppInfo {
  final String name;
  final String bundleId;
  final String executableName;

  ActiveAppInfo({
    required this.name,
    required this.bundleId,
    required this.executableName,
  });

  factory ActiveAppInfo.fromMap(Map<String, dynamic> map) {
    return ActiveAppInfo(
      name: map['name'] ?? 'Unknown',
      bundleId: map['bundleId'] ?? 'Unknown',
      executableName: map['executableName'] ?? 'Unknown',
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
      final result = await _channel.invokeMapMethod<String, dynamic>('getActiveApp');
      if (result != null) {
        return ActiveAppInfo.fromMap(result);
      }
    } on PlatformException catch (e) {
      _logger.error('Failed to get active app: ${e.message}');
    }
    return null;
  }
}
