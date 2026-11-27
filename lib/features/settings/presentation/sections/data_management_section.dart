import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:breakmate/core/errors/app_exception.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/utils/toast.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/features/analytics/stats_service.dart'
    show StatsService;
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/features/analytics/app_usage_models.dart';
import 'package:breakmate/features/analytics/break_history_service.dart';
import 'package:breakmate/features/analytics/focus_session_service.dart';
import 'package:breakmate/core/utils/file_permissions.dart';
import 'package:breakmate/features/settings/local_data_wiper.dart';
import 'package:breakmate/features/settings/backup_service.dart';
import 'package:intl/intl.dart';

/// Settings > Data: JSON backup export/import, CSV stats export/import and full data wipe.
class DataManagementSection extends StatefulWidget {
  const DataManagementSection({super.key});

  @override
  State<DataManagementSection> createState() => _DataManagementSectionState();
}

class _DataManagementSectionState extends State<DataManagementSection> {
  final StorageService _storage = sl<StorageService>();
  int _dbSizeBytes = 0;
  bool _isLoading = true;
  late final _backups = BackupService(_storage);
  List<File> _localBackups = const [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final size = await _storage.getDatabaseSize();
    final local = await _backups.list();
    if (mounted) {
      setState(() {
        _dbSizeBytes = size;
        _localBackups = local;
        _isLoading = false;
      });
    }
  }

  static String _stamp() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}-${two(n.month)}-${two(n.day)}_${two(n.hour)}${two(n.minute)}';
  }

  // Appends the extension when the picker omits it and restricts file permissions to the owner.
  Future<String?> _saveText(
    String dialogTitle,
    String fileName,
    String ext,
    String content,
  ) async {
    final path = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [ext],
    );
    if (path == null) return null;
    final target = path.toLowerCase().endsWith('.$ext') ? path : '$path.$ext';
    final file = File(target);
    await file.writeAsString(content);
    await restrictToOwner(file.path);
    return target;
  }

  Future<({String path, String content})?> _pickFile(List<String> exts) async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Import data',
      type: FileType.custom,
      allowedExtensions: exts,
    );
    final path = result?.files.single.path;
    if (path == null) return null;
    return (path: path, content: await File(path).readAsString());
  }

  Future<void> _exportBackupJson() async {
    try {
      final saved = await _saveText(
        'Export backup',
        'breakmate_backup_${_stamp()}.json',
        'json',
        const JsonEncoder.withIndent('  ').convert(_backups.build()),
      );
      if (saved != null && mounted) {
        Toast.showSuccess(context, 'Backup saved to $saved');
      }
    } catch (e) {
      if (mounted) Toast.showError(context, 'Failed to export backup: $e');
    }
  }

  Future<void> _exportStatsTable({
    String delimiter = ',',
    String ext = 'csv',
  }) async {
    try {
      final stats = _backups.dailyStats()
        ..sort((a, b) => '${b['date']}'.compareTo('${a['date']}'));

      final header = [
        'Date',
        'BreaksCompleted',
        'BreaksSkipped',
        'UsageMinutes',
        'WellnessActions',
      ].join(delimiter);
      final buffer = StringBuffer()..writeln(header);
      for (final s in stats) {
        buffer.writeln(
          [
            s['date'],
            s['breaksCompleted'] ?? 0,
            s['breaksSkipped'] ?? 0,
            s['usageMinutes'] ?? 0,
            s['wellnessActions'] ?? 0,
          ].join(delimiter),
        );
      }

      final saved = await _saveText(
        'Export stats (${ext.toUpperCase()})',
        'breakmate_stats_${_stamp()}.$ext',
        ext,
        buffer.toString(),
      );
      if (saved != null && mounted) {
        Toast.showSuccess(context, 'Stats exported to $saved');
      }
    } catch (e) {
      if (mounted) {
        Toast.showError(context, 'Could not export ${ext.toUpperCase()}');
      }
    }
  }

  Future<void> _exportHistory() async {
    try {
      final rows = <(DateTime, String, String)>[
        for (final b in sl<BreakHistoryService>().events)
          (b.time, 'break', b.completed ? 'completed' : 'skipped'),
        for (final s in sl<FocusSessionService>().sessionsForPeriod(
          UsagePeriod.month,
        ))
          (s.start, 'focus', '${s.durationSeconds ~/ 60} min'),
      ]..sort((a, b) => b.$1.compareTo(a.$1));
      final buffer = StringBuffer()..writeln('Time,Type,Detail');
      for (final r in rows) {
        buffer.writeln('${r.$1.toIso8601String()},${r.$2},${r.$3}');
      }
      final saved = await _saveText(
        'Export history',
        'breakmate_history_${_stamp()}.csv',
        'csv',
        buffer.toString(),
      );
      if (saved != null && mounted) {
        Toast.showSuccess(context, 'History exported to $saved');
      }
    } catch (e) {
      if (mounted) Toast.showError(context, 'Failed to export history: $e');
    }
  }

  Future<void> _showExportOptions() async {
    final choice = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Export as'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'json'),
            child: const Text('JSON — full backup (settings, stats, activity)'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'csv'),
            child: const Text('CSV — daily stats'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'history'),
            child: const Text('CSV — break & focus history'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'tsv'),
            child: const Text('TSV — daily stats (tab separated)'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
    switch (choice) {
      case 'json':
        await _exportBackupJson();
      case 'csv':
        await _exportStatsTable();
      case 'history':
        await _exportHistory();
      case 'tsv':
        await _exportStatsTable(delimiter: '\t', ext: 'tsv');
    }
  }

  Future<void> _importData() async {
    try {
      final picked = await _pickFile(['json', 'csv', 'tsv']);
      if (picked == null) return;
      final isJson =
          picked.path.toLowerCase().endsWith('.json') ||
          picked.content.trimLeft().startsWith('{');
      if (isJson) {
        await _importBackupJson(picked.content);
      } else {
        await _importStatsTable(picked.content);
      }
    } catch (e) {
      if (mounted) await _showReport("Couldn't read this file", _reason(e));
    }
  }

  Future<bool> _confirmReplace(String what, [String note = '']) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Replace existing data?'),
        content: Text('Importing will replace your current $what.$note'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  static String _reason(Object error) =>
      error is AppException ? error.message : '$error';

  static String _bullets(List<String> lines) =>
      lines.map((line) => '• $line').join('\n\n');

  Future<void> _showReport(String title, String body) =>
      showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );

  Future<void> _importBackupJson(String content) async {
    try {
      final data = BackupService.parse(content);
      final expected = _backups.check(data).issues;
      if (!await _confirmRestore(BackupService.preview(data), expected)) return;
      final issues = await _backups.restore(data);
      await _loadStats();
      if (!mounted) return;
      if (issues.isEmpty) {
        Toast.showSuccess(context, 'Backup restored');
      } else {
        await _showReport('Restored, with exceptions', _bullets(issues));
      }
    } catch (e) {
      if (mounted) await _showReport("Couldn't import this file", _reason(e));
    }
  }

  Future<bool> _confirmRestore(BackupPreview pv, List<String> issues) async {
    final when = pv.savedAt == null
        ? 'unknown date'
        : DateFormat.yMMMd().add_jm().format(pv.savedAt!);
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Restore this backup?'),
        content: Text(
          'Saved $when\n'
          '${pv.statDays} days of stats, ${pv.breaksCompleted} breaks'
          '${pv.hasSettings ? ', settings included' : ''}\n\n'
          'This replaces your current settings, statistics and activity history.'
          '${issues.isEmpty ? '' : '\n\nNot everything can be imported:\n\n'
                    '${_bullets(issues)}'}',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _restoreLocal(File f) async =>
      _importBackupJson(await f.readAsString());

  Future<void> _importStatsTable(String picked) async {
    try {
      final table = BackupService.parseStatsTable(picked);
      final statsList = table.rows;
      final skipped = table.skipped.isEmpty
          ? ''
          : '${table.skipped.length} rows can\'t be read and will be skipped '
                '(line ${table.skipped.take(10).join(', ')}).';
      if (!await _confirmReplace(
        'daily statistics',
        skipped.isEmpty ? '' : '\n\n$skipped',
      )) {
        return;
      }

      statsList.sort((a, b) => a.date.compareTo(b.date));
      await _storage.setString(
        AppConstants.keyWeeklyStats,
        jsonEncode([for (final s in statsList) s.toMap()..remove('id')]),
      );

      // The counters hold today's numbers only.
      final now = DateTime.now();
      final today = DateFormat('yyyy-MM-dd').format(now);
      final todayRow = statsList.where((s) => s.date == today).firstOrNull;
      await _storage.setInt(
        AppConstants.keyBreaksCompleted,
        todayRow?.breaksCompleted ?? 0,
      );
      await _storage.setInt(
        AppConstants.keyBreaksSkipped,
        todayRow?.breaksSkipped ?? 0,
      );
      await _storage.setInt(
        AppConstants.keyDailyUsageMinutes,
        todayRow?.usageMinutes ?? 0,
      );

      if (sl.isRegistered<StatsService>()) {
        await sl<StatsService>().initialize();
      }
      await _loadStats();

      if (mounted) {
        Toast.showSuccess(
          context,
          'Imported ${statsList.length} days of stats'
          '${skipped.isEmpty ? '' : ', ${table.skipped.length} rows skipped'}',
        );
      }
    } catch (e) {
      if (mounted) await _showReport("Couldn't import this file", _reason(e));
    }
  }

  void _showResetConfirmation() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Reset all data'),
        content: const Text(
          'Are you sure you want to delete all settings, companion preferences, and statistics? This action is permanent and cannot be undone.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () async {
              Navigator.pop(context);
              await _clearAllData();
            },
            isDestructiveAction: true,
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  // Delegates to [wipeAllLocalData] then refreshes the displayed DB size.
  Future<void> _clearAllData() async {
    try {
      await wipeAllLocalData();
      await _loadStats();

      if (mounted) {
        Toast.showSuccess(context, 'All application data has been reset.');
      }
    } catch (e) {
      if (mounted) {
        Toast.showError(context, 'Failed to clear data: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: ProgressCircle());
    }

    final sizeMb = (_dbSizeBytes / (1024 * 1024)).toStringAsFixed(2);
    final migrationTime = _storage.migrationDurationMs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader('Storage'),
        buildCard([
          valueRow('Database size', '$sizeMb MB'),
          valueRow('Schema version', 'v1.1 (Production)'),
          valueRow(
            'Last migration',
            migrationTime == 0 ? 'N/A' : '${migrationTime}ms',
          ),
        ]),
        sectionHeader('Backup and restore'),
        buildCard([
          actionRow(
            label: 'Export',
            subtitle: 'JSON, CSV or TSV',
            buttonText: 'Export…',
            onPressed: _showExportOptions,
          ),
          actionRow(
            label: 'Import',
            subtitle: 'The file type is detected automatically',
            buttonText: 'Import…',
            onPressed: _importData,
          ),
          toggleRow(
            'Daily automatic backup',
            'Keeps the last ${BackupService.keepLast} days on this device',
            _backups.autoEnabled,
            (v) async {
              _backups.autoEnabled = v;
              await _backups.runIfDue();
              await _loadStats();
            },
          ),
          for (final f in _localBackups)
            actionRow(
              label: p
                  .basename(f.path)
                  .replaceFirst('breakmate_auto_', '')
                  .replaceFirst('.json', ''),
              subtitle: 'Local backup',
              buttonText: 'Restore',
              onPressed: () => _restoreLocal(f),
            ),
        ]),
        sectionHeader('Reset'),
        buildCard([
          actionRow(
            label: 'Clear all data',
            subtitle: 'Deletes all settings and local analytics history',
            buttonText: 'Reset…',
            onPressed: _showResetConfirmation,
            isDestructive: true,
          ),
        ]),
      ],
    );
  }
}
