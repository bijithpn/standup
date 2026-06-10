import 'dart:io';
import 'package:breakmate/core/utils/logger.dart';

class SystemMediaService {
  final AppLogger _logger = AppLogger();

  /// Pauses system media (Spotify/Apple Music on macOS, Global on Windows)
  Future<void> pauseMedia() async {
    try {
      if (Platform.isMacOS) {
        await _pauseMacOSMedia();
      } else if (Platform.isWindows) {
        await _pauseWindowsMedia();
      }
    } catch (e) {
      _logger.error('Failed to pause system media: $e');
    }
  }

  Future<void> _pauseMacOSMedia() async {
    await Process.run('osascript', [
      '-e',
      'if application "Spotify" is running then tell application "Spotify" to pause',
    ]);

    await Process.run('osascript', [
      '-e',
      'if application "Music" is running then tell application "Music" to pause',
    ]);

    _logger.info('MacOS media pause commands sent');
  }

  Future<void> _pauseWindowsMedia() async {
    await Process.run('powershell', [
      '-Command',
      '(New-Object -ComObject WScript.Shell).SendKeys([char]179)',
    ]);

    _logger.info('Windows media pause command sent');
  }
}
