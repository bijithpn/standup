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
        'daily_stats': _storage.dailyStatsBox
                ?.getAll()
                .map((e) => e.toMap())
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
        throw Exception("breakmate_backup.json not found in Downloads or Documents");
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

      // Reload settings repository to apply to UI immediately
      await sl<SettingsRepository>().load();
      await _loadStats();

      if (mounted) Toast.showSuccess(context, 'Backup restored successfully!');
    } catch (e) {
      if (mounted) Toast.showError(context, 'Failed to import backup: $e');
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
            '${migrationTime}ms',
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
                        backgroundColor: AppTheme.accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.cloud_upload, size: 16, color: AppTheme.accentColor),
                            const SizedBox(width: 8),
                            Text(
                              'Export Backup',
                              style: TextStyle(color: AppTheme.accentColor, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MinimalButton(
                        onPressed: _exportStatsCsv,
                        backgroundColor: AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.table, size: 16, color: AppTheme.textPrimary),
                            const SizedBox(width: 8),
                            const Text(
                              'Export CSV',
                              style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: MinimalButton(
                    onPressed: _importBackupJson,
                    isSecondary: true,
                    borderRadius: BorderRadius.circular(10),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.folder_badge_plus, size: 16, color: AppTheme.textSecondary),
                        const SizedBox(width: 8),
                        const Text(
                          'Restore JSON Backup from Downloads',
                          style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ]),

        sectionHeader(
          'Danger Zone',
          subtitle: 'Irreversible data actions.',
        ),
        buildCard([
          actionRow(
            label: 'Clear All Data',
            subtitle: 'Delete all settings and local analytics history.',
            buttonText: 'Reset',
            onPressed: () {
               // Show confirmation
            },
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
