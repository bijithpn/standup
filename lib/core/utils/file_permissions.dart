import 'dart:io';

/// Restricts [path] (file or directory) to the current user: `600` for files,
/// `700` for directories. Best-effort and a no-op on Windows, where the
/// user-profile ACLs already apply.
Future<void> restrictToOwner(String path, {bool directory = false}) async {
  if (Platform.isWindows) return;
  try {
    await Process.run('chmod', [directory ? '700' : '600', path]);
  } catch (_) {}
}
