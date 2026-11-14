import 'dart:io';

/// Restricts a file (0600) or directory (0700) to the current user; no-op on Windows and failures are ignored (best effort).
Future<void> restrictToOwner(String path, {bool directory = false}) async {
  if (Platform.isWindows) return;
  try {
    await Process.run('chmod', [directory ? '700' : '600', path]);
  } catch (_) {}
}
