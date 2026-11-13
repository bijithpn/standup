import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import 'package:breakmate/core/utils/file_permissions.dart';

/// Shared-secret file that authenticates IPC messages so only our own processes can talk to the running instance.
class SingleInstanceToken {
  static const _fileName = 'ipc.token';

  /// Generates a random 256-bit hex token and stores it owner-only; called by the primary instance at startup.
  static Future<String> create(Directory dir) async {
    final random = Random.secure();
    final token = List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final file = File(p.join(dir.path, _fileName));
    await file.writeAsString(token, flush: true);
    await restrictToOwner(file.path);
    return token;
  }

  static Future<String?> read(Directory dir) async {
    try {
      final file = File(p.join(dir.path, _fileName));
      if (!await file.exists()) return null;
      return (await file.readAsString()).trim();
    } catch (_) {
      return null;
    }
  }

  /// Expects `token payload`; returns the payload if the token matches, otherwise null.
  static String? authorize(String message, String? expected) {
    if (expected == null || expected.isEmpty) return null;
    final space = message.trim().indexOf(' ');
    if (space <= 0) return null;
    final token = message.substring(0, space);
    if (token != expected) return null;
    return message.substring(space + 1).trim();
  }
}
