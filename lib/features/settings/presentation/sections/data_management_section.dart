import 'dart:convert';
import 'dart:io';
import 'package:breakmate/core/errors/app_exception.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/core/utils/toast.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/shared/widgets/minimal_controls.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/core/storage/models/daily_stats.dart';
import 'package:breakmate/core/services/simple_prefs.dart';
import 'package:breakmate/core/storage/models/key_value_record.dart';
import 'package:breakmate/features/analytics/stats_service.dart'
    show StatsService;
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/core/utils/file_permissions.dart';
import 'package:breakmate/features/settings/local_data_wiper.dart';

class DataManagementSection extends StatefulWidget {
  const DataManagementSection({super.key});

  @override
  State<DataManagementSection> createState() => _DataManagementSectionState();
}

class _DataManagementSectionState extends State<DataManagementSection> {
  final StorageService _storage = sl<StorageService>();
  int _dbSizeBytes = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final size = await _storage.getDatabaseSize();
    if (mounted) {
      setState(() {
        _dbSizeBytes = size;
        _isLoading = false;
      });
    }
  }

  static String _stamp() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}-${two(n.month)}-${two(n.day)}_${two(n.hour)}${two(n.minute)}';
  }

  /// Asks the user where to save, so the export works inside the macOS sandbox
  /// and never silently overwrites an earlier file. Returns the path, or null
  /// if cancelled.
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

  /// Lets the user choose a backup file; null if cancelled.
  Future<({String path, String content})?> _pickFile(List<String> exts) async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Import Data',
      type: FileType.custom,
      allowedExtensions: exts,
    );
    final path = result?.files.single.path;
    if (path == null) return null;
    return (path: path, content: await File(path).readAsString());
  }

  Future<void> _exportBackupJson() async {
    try {
      final backup = <String, dynamic>{
        'schemaVersion': AppConstants.backupSchemaVersion,
        'timestamp': DateTime.now().toIso8601String(),
        // The app's own settings format, so restore reads back what it wrote.
        'settingsFormat': 'model',
        'settings': sl<SettingsRepository>().currentSettings.toMap(),
        'companion': _storage.companionPreferencesBox?.get(1)?.toMap() ?? {},
        'global_stats': _storage.globalStatsBox?.get(1)?.toMap() ?? {},
        'daily_stats':
            _storage.dailyStatsBox?.getAll().map((e) => e.toMap()).toList() ??
            [],
        'kv_records':
            _storage.kvBox
                ?.getAll()
                .map((e) => {'key': e.key, 'value': e.value, 'type': e.type})
                .toList() ??
            [],
      };

      final saved = await _saveText(
        'Export Backup',
        'breakmate_backup_${_stamp()}.json',
        'json',
        const JsonEncoder.withIndent('  ').convert(backup),
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
      final stats = _storage.dailyStatsBox?.getAll() ?? [];
      stats.sort((a, b) => b.date.compareTo(a.date));

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
            s.date,
            s.breaksCompleted,
            s.breaksSkipped,
            s.usageMinutes,
            s.wellnessActions,
          ].join(delimiter),
        );
      }

      final saved = await _saveText(
        'Export Stats (${ext.toUpperCase()})',
        'breakmate_stats_${_stamp()}.$ext',
        ext,
        buffer.toString(),
      );
      if (saved != null && mounted) {
        Toast.showSuccess(context, 'Stats exported to $saved');
      }
    } catch (e) {
      if (mounted) {
        Toast.showError(context, 'Failed to export ${ext.toUpperCase()}: $e');
      }
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
            child: const Text('JSON — full backup (settings + stats)'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'csv'),
            child: const Text('CSV — daily stats'),
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
      case 'tsv':
        await _exportStatsTable(delimiter: '\t', ext: 'tsv');
    }
  }

  /// One import entry point: the file's type decides how it is read.
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
      if (mounted) Toast.showError(context, 'Failed to import: $e');
    }
  }

  Future<bool> _confirmReplace(String what) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Replace existing data?'),
        content: Text('Importing will replace your current $what.'),
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

  Future<void> _importBackupJson(String content) async {
    try {
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic> ||
          !decoded.containsKey('timestamp')) {
        throw AppException(
          type: AppErrorType.backup,
          message: "Invalid backup file format",
        );
      }
      final Map<String, dynamic> data = decoded;
      if (!await _confirmReplace('settings and statistics')) return;

      // Older backups stored the database's internal settings layout, which
      // the model cannot read; those restore through the key-value records.
      if (data['settingsFormat'] == 'model' &&
          data.containsKey('settings') &&
          data['settings'] is Map) {
        final settingsMap = Map<String, dynamic>.from(data['settings']);
        if (settingsMap.isNotEmpty) {
          final settingsModel = SettingsModel.fromMap(settingsMap);
          final repository = sl<SettingsRepository>();
          await repository.save(settingsModel);
        }
      }

      // Global and daily stats are restored directly because their ObjectBox
      if (data.containsKey('global_stats') && data['global_stats'] is Map) {
        final globalStatsMap = Map<String, dynamic>.from(data['global_stats']);
        if (globalStatsMap.isNotEmpty) {
          final globalStats = GlobalStats(
            id: 1,
            currentStreak: globalStatsMap['currentStreak'] ?? 0,
            longestStreak: globalStatsMap['longestStreak'] ?? 0,
            totalWorkSessions: globalStatsMap['totalWorkSessions'] ?? 0,
            lastActiveDate: globalStatsMap['lastActiveDate'] ?? '',
          );
          _storage.globalStatsBox?.put(globalStats);
        }
      }

      if (data.containsKey('daily_stats') && data['daily_stats'] is List) {
        final dailyList = data['daily_stats'] as List;
        _storage.dailyStatsBox?.removeAll();
        for (final item in dailyList) {
          if (item is Map) {
            final dailyStatsMap = Map<String, dynamic>.from(item);
            final dailyStats = DailyStats(
              id: 0,
              date: dailyStatsMap['date'] ?? '',
              breaksCompleted: dailyStatsMap['breaksCompleted'] ?? 0,
              breaksSkipped: dailyStatsMap['breaksSkipped'] ?? 0,
              usageMinutes: dailyStatsMap['usageMinutes'] ?? 0,
              wellnessActions: dailyStatsMap['wellnessActions'] ?? 0,
            );
            _storage.dailyStatsBox?.put(dailyStats);
          }
        }
      }

      if (data.containsKey('kv_records') && data['kv_records'] is List) {
        final kvList = data['kv_records'] as List;
        _storage.kvBox?.removeAll();
        for (final item in kvList) {
          if (item is Map) {
            final key = item['key'] as String?;
            final value = item['value'] as String?;
            final type = item['type'] as String?;
            if (key != null && value != null && type != null) {
              final record = KeyValueRecord(key: key, value: value, type: type);
              _storage.kvBox?.put(record);

              if (type == 'int') {
                final intVal = int.tryParse(value);
                if (intVal != null) SimplePrefs.instance.setInt(key, intVal);
              } else if (type == 'bool') {
                SimplePrefs.instance.setBool(key, value == 'true');
              } else if (type == 'string') {
                SimplePrefs.instance.setString(key, value);
              } else if (type == 'double') {
                final doubleVal = double.tryParse(value);
                if (doubleVal != null) {
                  SimplePrefs.instance.setDouble(key, doubleVal);
                }
              }
            }
          }
        }
      }

      await sl<SettingsRepository>().load();
      if (sl.isRegistered<StatsService>()) {
        await sl<StatsService>().initialize();
      }
      await _loadStats();

      if (mounted) Toast.showSuccess(context, 'Backup restored successfully!');
    } catch (e) {
      if (mounted) Toast.showError(context, 'Failed to import backup: $e');
    }
  }

  Future<void> _importStatsTable(String picked) async {
    try {
      // Spreadsheet apps often prepend a byte-order mark.
      final content = picked.replaceFirst('\uFEFF', '');
      final lines = content.split(RegExp(r'\r?\n'));
      if (lines.length <= 1) {
        throw AppException(
          type: AppErrorType.backup,
          message: "CSV file is empty",
        );
      }

      String clean(String v) => v.trim().replaceAll('"', '');
      final delimiter = lines.first.contains('\t')
          ? '\t'
          : lines.first.contains(';') && !lines.first.contains(',')
          ? ';'
          : ',';
      final header = lines.first
          .split(delimiter)
          .map((h) => clean(h).toLowerCase());
      final cols = header.toList();
      int col(String name, int fallback) {
        final i = cols.indexOf(name);
        return i >= 0 ? i : fallback;
      }

      final iDate = col('date', 0);
      final iDone = col('breakscompleted', 1);
      final iSkip = col('breaksskipped', 2);
      final iUsage = col('usageminutes', 3);
      final iWell = col('wellnessactions', 4);

      final List<DailyStats> statsList = [];
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        final parts = line.split(delimiter).map(clean).toList();
        String at(int idx) => idx < parts.length ? parts[idx] : '';
        final date = at(iDate);
        if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) continue;

        statsList.add(
          DailyStats(
            id: 0,
            date: date,
            breaksCompleted: int.tryParse(at(iDone)) ?? 0,
            breaksSkipped: int.tryParse(at(iSkip)) ?? 0,
            usageMinutes: int.tryParse(at(iUsage)) ?? 0,
            wellnessActions: int.tryParse(at(iWell)) ?? 0,
          ),
        );
      }

      if (statsList.isEmpty) {
        throw AppException(
          type: AppErrorType.backup,
          message: "No valid stats found in CSV",
        );
      }

      if (!await _confirmReplace('daily statistics')) return;
      _storage.dailyStatsBox?.removeAll();
      for (final s in statsList) {
        _storage.dailyStatsBox?.put(s);
      }

      statsList.sort((a, b) => a.date.compareTo(b.date));

      final jsonList = statsList
          .map(
            (e) => {
              'date': e.date,
              'breaksCompleted': e.breaksCompleted,
              'breaksSkipped': e.breaksSkipped,
              'usageMinutes': e.usageMinutes,
              'wellnessActions': e.wellnessActions,
            },
          )
          .toList();
      final String weeklyDataJson = jsonEncode(jsonList);

      await _storage.setString(AppConstants.keyWeeklyStats, weeklyDataJson);
      SimplePrefs.instance.setString(
        AppConstants.keyWeeklyStats,
        weeklyDataJson,
      );

      int totalCompleted = 0;
      int totalSkipped = 0;
      for (final s in statsList) {
        totalCompleted += s.breaksCompleted;
        totalSkipped += s.breaksSkipped;
      }

      await _storage.setInt(AppConstants.keyBreaksCompleted, totalCompleted);
      SimplePrefs.instance.setInt(
        AppConstants.keyBreaksCompleted,
        totalCompleted,
      );

      await _storage.setInt(AppConstants.keyBreaksSkipped, totalSkipped);
      SimplePrefs.instance.setInt(AppConstants.keyBreaksSkipped, totalSkipped);

      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      DailyStats? todayRow;
      for (final s in statsList) {
        if (s.date == todayStr) {
          todayRow = s;
          break;
        }
      }

      if (todayRow != null) {
        await _storage.setInt(
          AppConstants.keyDailyUsageMinutes,
          todayRow.usageMinutes,
        );
        SimplePrefs.instance.setInt(
          AppConstants.keyDailyUsageMinutes,
          todayRow.usageMinutes,
        );
      } else {
        await _storage.setInt(AppConstants.keyDailyUsageMinutes, 0);
        SimplePrefs.instance.setInt(AppConstants.keyDailyUsageMinutes, 0);
      }

      if (sl.isRegistered<StatsService>()) {
        await sl<StatsService>().initialize();
      }
      await _loadStats();

      if (mounted) {
        Toast.showSuccess(context, 'Stats imported from CSV successfully!');
      }
    } catch (e) {
      if (mounted) Toast.showError(context, 'Failed to import table: $e');
    }
  }

  void _showResetConfirmation() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Reset All Data'),
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
        sectionHeader(
          'Storage & Data',
          subtitle: 'Manage local database, backups, and analytics exports.',
        ),
        const SizedBox(height: 12),
        buildCard([
          _infoRow(
            'Database Size',
            '$sizeMb MB',
            CupertinoIcons.circle_grid_hex,
          ),
          divider(),
          _infoRow(
            'Schema Version',
            'v1.1 (Production)',
            CupertinoIcons.doc_text_viewfinder,
          ),
          divider(),
          _infoRow(
            'Last Migration',
            migrationTime == 0 ? 'N/A' : '${migrationTime}ms',
            CupertinoIcons.arrow_right_arrow_left_circle,
          ),
        ]),

        sectionHeader(
          'Backup & Restore',
          subtitle:
              'Export as JSON, CSV or TSV. Import detects the type automatically.',
        ),
        buildCard([
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Row(
              children: [
                Expanded(
                  child: MinimalButton(
                    onPressed: _showExportOptions,
                    isSecondary: true,
                    borderRadius: BorderRadius.circular(10),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.cloud_upload,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Export',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MinimalButton(
                    onPressed: _importData,
                    isSecondary: true,
                    borderRadius: BorderRadius.circular(10),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.folder_badge_plus,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Import',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ]),

        sectionHeader('Danger Zone', subtitle: 'Irreversible data actions.'),
        buildCard([
          actionRow(
            label: 'Clear All Data',
            subtitle: 'Delete all settings and local analytics history.',
            buttonText: 'Reset',
            onPressed: _showResetConfirmation,
            isDestructive: true,
          ),
        ]),
      ],
    );
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }
}
