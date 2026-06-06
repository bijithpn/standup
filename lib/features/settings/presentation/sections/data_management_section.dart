import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
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
import 'package:breakmate/features/analytics/stats_service.dart' show StatsService;
import 'package:breakmate/core/constants/app_constants.dart';

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

  Future<void> _exportBackupJson() async {
    try {
      Directory? dir;
      bool isDownloads = true;
      try {
        dir = await getDownloadsDirectory();
      } catch (_) {}

      if (dir == null) {
        dir = await getApplicationDocumentsDirectory();
        isDownloads = false;
      }

      final Map<String, dynamic> backup = {
        'timestamp': DateTime.now().toIso8601String(),
        'settings': _storage.settingsBox?.get(1)?.toMap() ?? {},
        'companion': _storage.companionPreferencesBox?.get(1)?.toMap() ?? {},
        'global_stats': _storage.globalStatsBox?.get(1)?.toMap() ?? {},
        'daily_stats':
            _storage.dailyStatsBox?.getAll().map((e) => e.toMap()).toList() ??
            [],
        'kv_records': _storage.kvBox
                ?.getAll()
                .map((e) => {
                      'key': e.key,
                      'value': e.value,
                      'type': e.type,
                    })
                .toList() ??
            [],
      };

      File file = File(p.join(dir.path, 'breakmate_backup.json'));
      try {
        await file.writeAsString(jsonEncode(backup));
      } catch (e) {
        if (isDownloads) {
          dir = await getApplicationDocumentsDirectory();
          isDownloads = false;
          file = File(p.join(dir.path, 'breakmate_backup.json'));
          await file.writeAsString(jsonEncode(backup));
        } else {
          rethrow;
        }
      }

      if (mounted) {
        Toast.showSuccess(
          context,
          isDownloads
              ? 'Backup saved to Downloads'
              : 'Backup saved to Documents (Downloads restricted)',
        );
      }
    } catch (e) {
      if (mounted) Toast.showError(context, 'Failed to export backup: $e');
    }
  }

  Future<void> _exportStatsCsv() async {
    try {
      Directory? dir;
      bool isDownloads = true;
      try {
        dir = await getDownloadsDirectory();
      } catch (_) {}

      if (dir == null) {
        dir = await getApplicationDocumentsDirectory();
        isDownloads = false;
      }

      final stats = _storage.dailyStatsBox?.getAll() ?? [];
      stats.sort((a, b) => b.date.compareTo(a.date));

      final buffer = StringBuffer();
      buffer.writeln(
        'Date,BreaksCompleted,BreaksSkipped,UsageMinutes,WellnessActions',
      );

      for (final s in stats) {
        buffer.writeln(
          '${s.date},${s.breaksCompleted},${s.breaksSkipped},${s.usageMinutes},${s.wellnessActions}',
        );
      }

      File file = File(p.join(dir.path, 'breakmate_stats.csv'));
      try {
        await file.writeAsString(buffer.toString());
      } catch (e) {
        if (isDownloads) {
          dir = await getApplicationDocumentsDirectory();
          isDownloads = false;
          file = File(p.join(dir.path, 'breakmate_stats.csv'));
          await file.writeAsString(buffer.toString());
        } else {
          rethrow;
        }
      }

      if (mounted) {
        Toast.showSuccess(
          context,
          isDownloads
              ? 'Stats exported to Downloads'
              : 'Stats exported to Documents (Downloads restricted)',
        );
      }
    } catch (e) {
      if (mounted) Toast.showError(context, 'Failed to export CSV: $e');
    }
  }

  Future<void> _importBackupJson() async {
    try {
      Directory? dir;
      try {
        dir = await getDownloadsDirectory();
      } catch (_) {}

      dir ??= await getApplicationDocumentsDirectory();

      File file = File(p.join(dir.path, 'breakmate_backup.json'));
      if (!await file.exists()) {
        final altDir = dir.path.contains('Downloads')
            ? await getApplicationDocumentsDirectory()
            : await getDownloadsDirectory();
        if (altDir != null) {
          final altFile = File(p.join(altDir.path, 'breakmate_backup.json'));
          if (await altFile.exists()) {
            file = altFile;
            dir = altDir;
          }
        }
      }

      if (!await file.exists()) {
        throw Exception(
          "breakmate_backup.json not found in Downloads or Documents",
        );
      }

      final content = await file.readAsString();
      final Map<String, dynamic> data = jsonDecode(content);

      if (!data.containsKey('timestamp')) {
        throw Exception("Invalid backup file format");
      }

      // Restore settings
      if (data.containsKey('settings') && data['settings'] is Map) {
        final settingsMap = Map<String, dynamic>.from(data['settings']);
        if (settingsMap.isNotEmpty) {
          final settingsModel = SettingsModel.fromMap(settingsMap);
          final repository = sl<SettingsRepository>();
          await repository.save(settingsModel);
        }
      }

      // Restore global stats
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

      // Restore daily stats
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

      // Restore key-value records (stats, streaks, etc.)
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

              // Mirror to SimplePrefs
              if (type == 'int') {
                final intVal = int.tryParse(value);
                if (intVal != null) SimplePrefs.instance.setInt(key, intVal);
              } else if (type == 'bool') {
                SimplePrefs.instance.setBool(key, value == 'true');
              } else if (type == 'string') {
                SimplePrefs.instance.setString(key, value);
              } else if (type == 'double') {
                final doubleVal = double.tryParse(value);
                if (doubleVal != null) SimplePrefs.instance.setDouble(key, doubleVal);
              }
            }
          }
        }
      }

      // Reload settings repository to apply to UI immediately
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

  Future<void> _importStatsCsv() async {
    try {
      Directory? dir;
      try {
        dir = await getDownloadsDirectory();
      } catch (_) {}

      dir ??= await getApplicationDocumentsDirectory();

      File file = File(p.join(dir.path, 'breakmate_stats.csv'));
      if (!await file.exists()) {
        final altDir = dir.path.contains('Downloads')
            ? await getApplicationDocumentsDirectory()
            : await getDownloadsDirectory();
        if (altDir != null) {
          final altFile = File(p.join(altDir.path, 'breakmate_stats.csv'));
          if (await altFile.exists()) {
            file = altFile;
            dir = altDir;
          }
        }
      }

      if (!await file.exists()) {
        throw Exception(
          "breakmate_stats.csv not found in Downloads or Documents",
        );
      }

      final content = await file.readAsString();
      final lines = content.split(RegExp(r'\r?\n'));
      if (lines.length <= 1) {
        throw Exception("CSV file is empty");
      }

      final List<DailyStats> statsList = [];
      // Skip header
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        final parts = line.split(',');
        if (parts.length >= 4) {
          final date = parts[0].trim();
          final breaksCompleted = int.tryParse(parts[1].trim()) ?? 0;
          final breaksSkipped = int.tryParse(parts[2].trim()) ?? 0;
          final usageMinutes = int.tryParse(parts[3].trim()) ?? 0;
          final wellnessActions = parts.length > 4 ? (int.tryParse(parts[4].trim()) ?? 0) : 0;

          statsList.add(DailyStats(
            id: 0,
            date: date,
            breaksCompleted: breaksCompleted,
            breaksSkipped: breaksSkipped,
            usageMinutes: usageMinutes,
            wellnessActions: wellnessActions,
          ));
        }
      }

      if (statsList.isEmpty) {
        throw Exception("No valid stats found in CSV");
      }

      // Write to DailyStatsBox
      _storage.dailyStatsBox?.removeAll();
      for (final s in statsList) {
        _storage.dailyStatsBox?.put(s);
      }

      // Sort chronologically for weekly_stats JSON
      statsList.sort((a, b) => a.date.compareTo(b.date));

      // Build weekly_stats JSON
      final jsonList = statsList.map((e) => {
        'date': e.date,
        'breaksCompleted': e.breaksCompleted,
        'breaksSkipped': e.breaksSkipped,
        'usageMinutes': e.usageMinutes,
        'wellnessActions': e.wellnessActions,
      }).toList();
      final String weeklyDataJson = jsonEncode(jsonList);

      await _storage.setString(AppConstants.keyWeeklyStats, weeklyDataJson);
      SimplePrefs.instance.setString(AppConstants.keyWeeklyStats, weeklyDataJson);

      // Sum totals
      int totalCompleted = 0;
      int totalSkipped = 0;
      for (final s in statsList) {
        totalCompleted += s.breaksCompleted;
        totalSkipped += s.breaksSkipped;
      }

      await _storage.setInt(AppConstants.keyBreaksCompleted, totalCompleted);
      SimplePrefs.instance.setInt(AppConstants.keyBreaksCompleted, totalCompleted);

      await _storage.setInt(AppConstants.keyBreaksSkipped, totalSkipped);
      SimplePrefs.instance.setInt(AppConstants.keyBreaksSkipped, totalSkipped);

      // Check if we have today's row to restore daily counts
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      DailyStats? todayRow;
      for (final s in statsList) {
        if (s.date == todayStr) {
          todayRow = s;
          break;
        }
      }

      if (todayRow != null) {
        await _storage.setInt(AppConstants.keyDailyUsageMinutes, todayRow.usageMinutes);
        SimplePrefs.instance.setInt(AppConstants.keyDailyUsageMinutes, todayRow.usageMinutes);
      } else {
        await _storage.setInt(AppConstants.keyDailyUsageMinutes, 0);
        SimplePrefs.instance.setInt(AppConstants.keyDailyUsageMinutes, 0);
      }

      // Re-initialize stats service
      if (sl.isRegistered<StatsService>()) {
        await sl<StatsService>().initialize();
      }
      await _loadStats();

      if (mounted) Toast.showSuccess(context, 'Stats imported from CSV successfully!');
    } catch (e) {
      if (mounted) Toast.showError(context, 'Failed to import CSV: $e');
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
      // Clear database boxes
      _storage.settingsBox?.removeAll();
      _storage.companionPreferencesBox?.removeAll();
      _storage.globalStatsBox?.removeAll();
      _storage.dailyStatsBox?.removeAll();
      _storage.kvBox?.removeAll();

      // Clear SimplePrefs
      SimplePrefs.instance.clear();

      // Reload settings repository & stats service
      await sl<SettingsRepository>().load();
      if (sl.isRegistered<StatsService>()) {
        await sl<StatsService>().initialize();
      }
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
          subtitle: 'Securely move your data between devices.',
        ),
        buildCard([
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: MinimalButton(
                        onPressed: _exportBackupJson,
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
                            const Text(
                              'Export Backup',
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
                        onPressed: _exportStatsCsv,
                        isSecondary: true,
                        borderRadius: BorderRadius.circular(10),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.table,
                              size: 16,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Export CSV',
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: MinimalButton(
                        onPressed: _importBackupJson,
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
                            const Text(
                              'Restore JSON',
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
                        onPressed: _importStatsCsv,
                        isSecondary: true,
                        borderRadius: BorderRadius.circular(10),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.table_badge_more,
                              size: 16,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Import CSV',
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
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
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
