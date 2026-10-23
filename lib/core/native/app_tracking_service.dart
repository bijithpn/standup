import 'dart:async';
import 'package:clock/clock.dart';
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

  /// Meeting detection, app-usage tracking and the wellness engine all ask for
  /// the active app on their own timers, and their ticks often land together.
  /// Callers asking for the same detail within this window share one native
  /// lookup. Short enough that no poller sees a stale app for a whole tick.
  static const Duration _shareWindow = Duration(milliseconds: 1500);
  final Map<String, ({DateTime at, Future<ActiveAppInfo?> result})> _recent =
      {};

  /// By default only the app identity is read. The window title and the
  /// browser tab URL are privacy-sensitive, so the native side fetches them
  /// only when a caller explicitly asks.
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
