import 'dart:io';
import 'package:flutter/foundation.dart';
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
    // Pause Spotify
    await Process.run('osascript', [
      '-e',
      'if application "Spotify" is running then tell application "Spotify" to pause'
    ]);

    // Pause Apple Music
    await Process.run('osascript', [
      '-e',
      'if application "Music" is running then tell application "Music" to pause'
    ]);
    
    _logger.info('MacOS media pause commands sent');
  }

  Future<void> _pauseWindowsMedia() async {
    // Send a global Media Play/Pause key (0xB3 / 179)
    // This is a toggle, but most media players treat it as pause if playing.
    // Tricky to detect if it's already paused without native bridge, 
    // but the roadmap specifically asks for auto-pause.
    await Process.run('powershell', [
      '-Command',
      '(New-Object -ComObject WScript.Shell).SendKeys([char]179)'
    ]);
    
    _logger.info('Windows media pause command sent');
  }
}
