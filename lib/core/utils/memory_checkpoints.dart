import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Memory checkpoint logger for BreakMate long-session testing.
/// Enable by setting [kEnableMemoryCheckpoints] to `true` (debug builds only).
/// Logs memory usage at key app lifecycle points.
/// Usage:
///   MemoryCheckpoints.instance.logCheckpoint('startup');
///   MemoryCheckpoints.instance.logCheckpoint('after_companion_show');
const bool kEnableMemoryCheckpoints = false;

class MemoryCheckpoints {
  MemoryCheckpoints._();
  static final MemoryCheckpoints instance = MemoryCheckpoints._();

  void logCheckpoint(String label) {
    if (!kDebugMode || !kEnableMemoryCheckpoints) return;

    // Get current memory info
    final info = ProcessInfo.currentRss;
    final heapMB = (info / (1024 * 1024)).toStringAsFixed(1);

    developer.log(
      '[MemoryCheckpoint] $label: ${heapMB}MB RSS',
      name: 'BreakMate-Memory',
    );

    if (kDebugMode) {
      debugPrint('[Memory] $label: ${heapMB}MB RSS');
    }
  }

  /// Log all standard checkpoints for long-session testing
  void logStandardCheckpoints() {
    if (!kDebugMode || !kEnableMemoryCheckpoints) return;

    logCheckpoint('startup');
    // Other checkpoints called manually at appropriate times:
    // after_first_companion_show
    // after_pet_theme_switch_5x
    // after_ten_break_overlays
    // after_one_hour_idle
  }
}
