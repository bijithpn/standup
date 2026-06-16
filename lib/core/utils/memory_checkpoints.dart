import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';

const bool kEnableMemoryCheckpoints = false;

class MemoryCheckpoints {
  MemoryCheckpoints._();
  static final MemoryCheckpoints instance = MemoryCheckpoints._();

  void logCheckpoint(String label) {
    if (!kDebugMode || !kEnableMemoryCheckpoints) return;

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

  void logStandardCheckpoints() {
    if (!kDebugMode || !kEnableMemoryCheckpoints) return;

    logCheckpoint('startup');
  }
}
