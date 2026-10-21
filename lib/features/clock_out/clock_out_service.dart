import 'dart:convert';
import 'dart:io';
import 'package:breakmate/core/services/storage_service.dart';

class ClockOutEntry {
  final DateTime timestamp;
  final String content;

  ClockOutEntry({required this.timestamp, required this.content});

  Map<String, dynamic> toMap() => {
    'timestamp': timestamp.toIso8601String(),
    'content': content,
  };

  factory ClockOutEntry.fromMap(Map<String, dynamic> map) => ClockOutEntry(
    timestamp: DateTime.parse(map['timestamp'] as String),
    content: map['content'] as String,
  );
}

class ClockOutService {
  static const _storageKey = 'clock_out_entries_v1';
  final StorageService _storage;

  ClockOutService(this._storage);

  Future<void> saveEntry(String content) async {
    final entries = await getEntries();
    entries.insert(
      0,
      ClockOutEntry(timestamp: DateTime.now(), content: content),
    );
    final encoded = jsonEncode(entries.map((e) => e.toMap()).toList());
    await _storage.setString(_storageKey, encoded);
  }

  Future<List<ClockOutEntry>> getEntries() async {
    final raw = _storage.getString(_storageKey);
    if (raw.isEmpty) return [];
    try {
      final List decoded = jsonDecode(raw) as List;
      return decoded
          .map((e) => ClockOutEntry.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<File> exportEntriesToMarkdown(String targetPath) async {
    final entries = await getEntries();
    final buffer = StringBuffer(
      '# Breakmate Daily Clock-Out Reflection Notes\n\n',
    );
    for (final entry in entries) {
      buffer.writeln('## ${entry.timestamp.toLocal()}');
      buffer.writeln(entry.content);
      buffer.writeln('\n---\n');
    }
    final file = File(targetPath);
    return file.writeAsString(buffer.toString());
  }
}
