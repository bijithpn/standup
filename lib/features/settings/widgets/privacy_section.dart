import 'package:breakmate/core/config/productivity_config.dart';
import 'package:breakmate/features/analytics/presentation/productivity/activity_tracking_intro.dart';
import 'package:breakmate/features/analytics/segments/activity_segment_repository.dart';
import 'package:breakmate/features/analytics/segments/productivity_repository.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/analytics/app_usage_models.dart';
import 'package:breakmate/features/analytics/app_usage_service.dart';
import 'package:breakmate/features/analytics/presentation/widgets/app_usage_section.dart';
import 'package:breakmate/features/analytics/presentation/widgets/category_budgets_card.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

class PrivacySection extends StatefulWidget {
  final SettingsModel settings;
  final ValueChanged<SettingsModel> onSave;

  const PrivacySection({super.key, required this.settings, required this.onSave});

  @override
  State<PrivacySection> createState() => _PrivacySectionState();
}

class _PrivacySectionState extends State<PrivacySection> {
  int _selectedFilter = 0; // 0: Today, 1: Week, 2: Month

  /// How many activity entries are stored, so "clear history" can say what it
  /// would actually delete.
  int _segmentCount = 0;

  @override
  void initState() {
    super.initState();
    _refreshSegmentCount();
  }

  UsagePeriod get _usagePeriod {
    switch (_selectedFilter) {
      case 1:
        return UsagePeriod.week;
      case 2:
        return UsagePeriod.month;
      default:
        return UsagePeriod.today;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader(
          'Privacy Report',
          subtitle:
              'Your data is yours. Learn how BreakMate protects your privacy.',
        ),
        const SizedBox(height: 16),

        buildCard([
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Local-Only Storage',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'All your settings, break history, and productivity stats are stored locally on this machine using ObjectBox. We do not have servers and we do not collect your personal data.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          divider(),
          _settingsInfoTile(
            context,
            title: 'Native Integrations',
            subtitle:
                'Meeting detection and active app tracking run entirely on your OS. We only check for specific keywords locally to suggest relevant breaks.',
            icon: LucideIcons.cpu,
          ),
          divider(),
          _settingsInfoTile(
            context,
            title: 'Calendar Access',
            subtitle:
                'If enabled, we only read event start/end times to avoid interrupting your work. Event titles and details are never processed or saved.',
            icon: LucideIcons.calendar,
          ),
        ]),

        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: sectionHeader(
                'App Usage Dashboard',
                subtitle:
                    'A transparent look at exactly what BreakMate has recorded about your app usage.',
              ),
            ),
            if (settings.appUsageTrackingEnabled)
              segmentedControl(
                ['Today', 'Week', 'Month'],
                _selectedFilter,
                (i) => setState(() => _selectedFilter = i),
                isSmall: true,
              ),
          ],
        ),
        const SizedBox(height: 16),

        buildCard([
          toggleRow(
            'Track App Usage',
            'See which apps you use most, here and on the Productivity screen. '
                'Only app names and time spent are stored, locally — never window titles or URLs.',
            settings.appUsageTrackingEnabled,
            (value) => _setTracking(settings, value),
          ),
        ]),

        if (settings.appUsageTrackingEnabled) ...[
          const SizedBox(height: 16),
          buildCard([
            dropdownRow(
              'Keep Activity History',
              ActivityRetention.fromDays(
                settings.activityHistoryRetentionDays,
              ).label,
              ActivityRetention.values.map((r) => r.label).toList(),
              (value) {
                if (value == null) return;
                widget.onSave(
                  settings.copyWith(
                    activityHistoryRetentionDays:
                        ActivityRetention.fromLabel(value).days,
                  ),
                );
              },
            ),
            divider(),
            actionRow(
              label: 'Clear Activity History',
              subtitle: _segmentCount == 0
                  ? 'No activity has been recorded yet.'
                  : '$_segmentCount recorded entries make up your timeline, '
                      'application totals and insights.',
              buttonText: 'Clear History',
              onPressed: _segmentCount == 0 ? null : _clearActivityHistory,
              isDestructive: true,
            ),
          ]),
        ],

        if (settings.appUsageTrackingEnabled) ...[
          const SizedBox(height: 16),
          CategoryBudgetsCard(
            budgetMinutes: settings.categoryDailyBudgetMinutes,
            onChanged: (updated) => widget.onSave(
              settings.copyWith(categoryDailyBudgetMinutes: updated),
            ),
          ),
        ],

        Consumer<AppUsageService>(
          builder: (context, usageService, _) {
            final period = _usagePeriod;
            return AppUsageSection(
              enabled: settings.appUsageTrackingEnabled,
              // No limit here: the Privacy dashboard's whole point is full
              // disclosure, so every tracked app is shown, not just the top 8.
              topApps: usageService.topApps(period, limit: null),
              categoryTotals: usageService.categoryTotals(period),
              iconCache: sl(),
              onEnable: () => widget.onSave(
                settings.copyWith(appUsageTrackingEnabled: true),
              ),
              listTitle: 'All Tracked Apps',
              // Daily budgets only mean something against today's totals.
              budgetMinutes: period == UsagePeriod.today
                  ? settings.categoryDailyBudgetMinutes
                  : const {},
            );
          },
        ),

        const SizedBox(height: 24),
        _DataTransparencyPanel(enabled: settings.appUsageTrackingEnabled),

        const SizedBox(height: 24),
        buildCard([
          actionRow(
            label: 'Delete All Local Data',
            subtitle:
                'This will reset all settings and wipe your statistics history. This cannot be undone.',
            buttonText: 'Wipe Data',
            onPressed: () {},
            isDestructive: true,
          ),
        ]),
      ],
    );
  }

  /// Turning tracking on for the first time explains itself before it starts;
  /// turning it off is immediate, because stopping never needs consent.
  Future<void> _setTracking(SettingsModel settings, bool value) async {
    if (!value) {
      widget.onSave(settings.copyWith(appUsageTrackingEnabled: false));
      return;
    }

    final accepted = await ActivityTrackingIntro.show(context);
    if (!accepted) return;

    widget.onSave(settings.copyWith(appUsageTrackingEnabled: true));
    _refreshSegmentCount();
  }

  Future<void> _clearActivityHistory() async {
    if (!sl.isRegistered<ActivitySegmentRepository>()) return;

    final confirmed = await ClearActivityHistoryDialog.show(
      context,
      segmentCount: _segmentCount,
    );
    if (!confirmed) return;

    sl<ActivitySegmentRepository>().clearAll();
    if (sl.isRegistered<ProductivityRepository>()) {
      sl<ProductivityRepository>().invalidate();
    }
    _refreshSegmentCount();
  }

  void _refreshSegmentCount() {
    if (!mounted) return;
    setState(() {
      _segmentCount = sl.isRegistered<ActivitySegmentRepository>()
          ? sl<ActivitySegmentRepository>().count()
          : 0;
    });
  }

  Widget _settingsInfoTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.accentColor),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Plain-language breakdown of exactly what the app usage feature stores,
/// how long it's kept, and what it never touches — the "what we know"
/// half of the dashboard, next to the "here's the data" half above.
class _DataTransparencyPanel extends StatelessWidget {
  final bool enabled;

  const _DataTransparencyPanel({required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.shieldCheck, size: 16, color: AppTheme.success),
              const SizedBox(width: 8),
              Text(
                'What exactly is stored',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _TransparencyRow(
            icon: LucideIcons.checkCircle2,
            iconColor: AppTheme.success,
            text: 'App name and category (e.g. "Xcode" — Development)',
          ),
          _TransparencyRow(
            icon: LucideIcons.checkCircle2,
            iconColor: AppTheme.success,
            text: 'Seconds spent per app, per day',
          ),
          _TransparencyRow(
            icon: LucideIcons.xCircle,
            iconColor: AppTheme.error,
            text: 'Window titles — never recorded',
          ),
          _TransparencyRow(
            icon: LucideIcons.xCircle,
            iconColor: AppTheme.error,
            text: 'URLs, documents, or file names — never recorded',
          ),
          _TransparencyRow(
            icon: LucideIcons.xCircle,
            iconColor: AppTheme.error,
            text: 'Nothing is ever sent off this device',
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.clock, size: 15, color: AppTheme.info),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    enabled
                        ? 'History rolls off automatically after 30 days — nothing older than that is ever kept.'
                        : 'Tracking is off, so nothing new is being recorded. Any history already on this device still ages out after 30 days.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransparencyRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;

  const _TransparencyRow({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
