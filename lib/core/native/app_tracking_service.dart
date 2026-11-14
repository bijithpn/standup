import 'dart:async';
import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:breakmate/core/utils/logger.dart';

/// Snapshot of the frontmost app; [url] is only set when the browser URL was requested.
class ActiveAppInfo {
  final String name;
  final String bundleId;
  final String executableName;

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

/// Queries the native side for the frontmost app and its icon; used by activity tracking and meeting detection.
class AppTrackingService {
  static const _channel = MethodChannel('com.breakmate/app_tracking');
  final AppLogger _logger = AppLogger();

  // Concurrent callers within this window share one native call instead of each hitting the platform channel.
  static const Duration _shareWindow = Duration(milliseconds: 1500);
  final Map<String, ({DateTime at, Future<ActiveAppInfo?> result})> _recent =
      {};

  /// Returns the active app, reusing an in-flight/recent result per (title, url) option combo.
  Future<ActiveAppInfo?> getActiveApp({
    bool includeTitle = false,
    bool includeUrl = false,
  }) {
    final key = '$includeTitle:$includeUrl';
    final now = clock.now();
    final recent = _recent[key];
    if (recent != null && now.difference(recent.at) < _shareWindow) {
      return recent.result;
    }
    final result = _fetchActiveApp(
      includeTitle: includeTitle,
      includeUrl: includeUrl,
    );
    _recent[key] = (at: now, result: result);
    return result;
  }

  Future<ActiveAppInfo?> _fetchActiveApp({
    required bool includeTitle,
    required bool includeUrl,
  }) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'getActiveApp',
        {'includeTitle': includeTitle, 'includeUrl': includeUrl},
      );
      if (result != null) {
        return ActiveAppInfo.fromMap(result);
      }
    } on PlatformException catch (e) {
      _logger.error('Failed to get active app: ${e.message}');
    }
    return null;
  }

  Future<Uint8List?> getAppIcon({
    String? bundleId,
    String? executableName,
  }) async {
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
