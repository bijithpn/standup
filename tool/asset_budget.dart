import 'dart:io';
import 'package:path/path.dart' as p;

const int kMaxAssetBudgetBytes = 20 * 1024 * 1024; // 20 MB

void main() {
  final assetsDir = Directory('assets');
  if (!assetsDir.existsSync()) {
    exit(1);
  }

  int totalBytes = 0;
  final List<MapEntry<String, int>> fileSizes = [];

  for (final entity in assetsDir.listSync(recursive: true)) {
    if (entity is File) {
      final size = entity.lengthSync();
      totalBytes += size;
      fileSizes.add(MapEntry(p.relative(entity.path, from: '.'), size));
    }
  }

  fileSizes.sort((a, b) => b.value.compareTo(a.value));

  stdout.writeln(
    'Asset total: ${_formatBytes(totalBytes)} '
    '(${fileSizes.length} files, budget ${_formatBytes(kMaxAssetBudgetBytes)})',
  );
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
    exit(1);
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
