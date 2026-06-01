import 'dart:io';
import 'package:path/path.dart' as p;

const int kMaxAssetBudgetBytes = 20 * 1024 * 1024; // 20 MB

void main(List<String> args) {
  final warnOnly = args.contains('--warn-only');
  final assetsDir = Directory('assets');
  if (!assetsDir.existsSync()) {
    exit(1);
  }

  int totalBytes = 0;
  final List<MapEntry<String, int>> fileSizes = [];
  final Map<String, int> categorySizes = {};

  for (final entity in assetsDir.listSync(recursive: true)) {
    if (entity is File) {
      final size = entity.lengthSync();
      final relativePath = p.relative(entity.path, from: '.');
      totalBytes += size;
      fileSizes.add(MapEntry(relativePath, size));

      final parts = p.split(relativePath);
      final category = parts.length >= 2
          ? p.join(parts[0], parts[1])
          : parts.first;
      categorySizes.update(
        category,
        (value) => value + size,
        ifAbsent: () => size,
      );
    }
  }

  fileSizes.sort((a, b) => b.value.compareTo(a.value));
  final categories = categorySizes.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  stdout.writeln(
    'Asset total: ${_formatBytes(totalBytes)} '
    '(${fileSizes.length} files, budget ${_formatBytes(kMaxAssetBudgetBytes)})',
  );
  stdout.writeln('Top asset categories:');
  for (int i = 0; i < 10 && i < categories.length; i++) {
    final entry = categories[i];
    stdout.writeln(
      '${(i + 1).toString().padLeft(2)}. '
      '${_formatBytes(entry.value).padLeft(8)}  ${entry.key}',
    );
  }

  stdout.writeln('');
  stdout.writeln('Top 20 assets:');

  for (int i = 0; i < 20 && i < fileSizes.length; i++) {
    final entry = fileSizes[i];
    stdout.writeln(
      '${(i + 1).toString().padLeft(2)}. '
      '${_formatBytes(entry.value).padLeft(8)}  ${entry.key}',
    );
  }

  if (totalBytes > kMaxAssetBudgetBytes) {
    stderr.writeln(
      'Asset budget exceeded by '
      '${_formatBytes(totalBytes - kMaxAssetBudgetBytes)}',
    );
    if (!warnOnly) exit(1);
  }
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '$bytes B';
}
