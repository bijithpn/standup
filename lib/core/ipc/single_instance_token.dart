import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import 'package:breakmate/core/utils/file_permissions.dart';

/// Shared secret for the loopback single-instance socket.
///
/// The socket is reachable by every local user, so commands must carry a token
/// that only the owning user can read from the application-support directory.
class SingleInstanceToken {
  static const _fileName = 'ipc.token';

  /// Creates a fresh token for this running instance and stores it owner-only.
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

  /// Splits `"<token> <command>"`; returns the command only when the token
  /// matches [expected], otherwise `null`.
  static String? authorize(String message, String? expected) {
    if (expected == null || expected.isEmpty) return null;
    final space = message.trim().indexOf(' ');
    if (space <= 0) return null;
    final token = message.substring(0, space);
    if (token != expected) return null;
    return message.substring(space + 1).trim();
  }
}
