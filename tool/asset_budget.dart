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

  for (int i = 0; i < 20 && i < fileSizes.length; i++) {
    final entry = fileSizes[i];
    final _ = entry.value / 1024;
  }

  if (totalBytes > kMaxAssetBudgetBytes) {
    exit(1);
  } else {}
}
