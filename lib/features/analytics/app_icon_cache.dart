import 'dart:typed_data';
import 'package:breakmate/core/native/app_tracking_service.dart';

/// In-memory, per-session cache of app icon bytes, keyed by the same appKey
/// used by [AppUsageService]. Avoids re-fetching an icon over the platform
/// channel every time a list rebuilds.
class AppIconCache {
  final AppTrackingService _appTracking;
  final Map<String, Uint8List?> _cache = {};

  AppIconCache({required AppTrackingService appTracking})
    : _appTracking = appTracking;

  Future<Uint8List?> iconFor({
    required String appKey,
    String? bundleId,
    String? executableName,
  }) async {
    if (_cache.containsKey(appKey)) return _cache[appKey];

    final icon = await _appTracking.getAppIcon(
      bundleId: bundleId,
      executableName: executableName,
    );
    _cache[appKey] = icon;
    return icon;
  }
}
