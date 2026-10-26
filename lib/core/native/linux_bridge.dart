import 'package:breakmate/core/native/windows_bridge.dart';

/// The Linux runner answers the same `com.breakmate.desktop/bridge` protocol as
/// the Windows one (no dock, no vibrancy, calendar unavailable), so the
/// implementation is shared and only the type differs.
class LinuxBridge extends WindowsBridge {}
