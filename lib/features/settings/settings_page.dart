import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';
import 'package:standup/app/dependency_injection.dart';
import 'package:standup/core/services/timer_engine.dart';
import 'package:standup/features/break_system/application/break_controller.dart';
import 'package:standup/features/settings/settings_model.dart';
import 'package:standup/features/settings/settings_repository.dart';
import 'package:standup/features/statistics/stats_model.dart';
import 'package:standup/features/statistics/stats_service.dart';
import 'package:standup/features/settings/break_profile.dart';
import 'package:standup/features/statistics/widgets/stats_chart.dart';
import 'package:standup/ui/theme/app_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late SettingsModel _settings;
  late StatsModel _stats;

  @override
  void initState() {
    super.initState();
    final repo = Provider.of<SettingsRepository>(context, listen: false);
    final statsService = Provider.of<StatsService>(context, listen: false);
    _settings = repo.currentSettings;
    _stats = statsService.load();
  }

  void _save(SettingsModel updated) {
    setState(() => _settings = updated);
    final repo = Provider.of<SettingsRepository>(context, listen: false);
    repo.save(updated);
    Provider.of<BreakController>(context, listen: false).refreshSettings();
  }

  @override
  Widget build(BuildContext context) {
    return MacosScaffold(
      toolBar: ToolBar(
        title: const Text('Settings'),
        titleWidth: 200,
      ),
      children: [
        ContentArea(
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader('ACTIVE PROFILE'),
                  const SizedBox(height: 12),
                  _buildProfileSelector(),
                  const SizedBox(height: 28),
                  _sectionHeader('SHORT BREAK'),
                  const SizedBox(height: 12),
                  _buildSettingsCard([
                    _sliderRow(
                      'Interval',
                      '${_settings.shortBreakIntervalMinutes} min',
                      _settings.shortBreakIntervalMinutes.toDouble(),
                      5,
                      60,
                      (v) => _save(_settings.copyWith(
                          shortBreakIntervalMinutes: v.round())),
                    ),
                    _divider(),
                    _sliderRow(
                      'Duration',
                      '${_settings.shortBreakDurationSeconds} sec',
                      _settings.shortBreakDurationSeconds.toDouble(),
                      10,
                      120,
                      (v) => _save(_settings.copyWith(
                          shortBreakDurationSeconds: v.round())),
                    ),
                  ]),
                  const SizedBox(height: 28),
                  _sectionHeader('LONG BREAK'),
                  const SizedBox(height: 12),
                  _buildSettingsCard([
                    _sliderRow(
                      'Interval',
                      '${_settings.longBreakIntervalMinutes} min',
                      _settings.longBreakIntervalMinutes.toDouble(),
                      15,
                      120,
                      (v) => _save(_settings.copyWith(
                          longBreakIntervalMinutes: v.round())),
                    ),
                    _divider(),
                    _sliderRow(
                      'Duration',
                      '${_settings.longBreakDurationMinutes} min',
                      _settings.longBreakDurationMinutes.toDouble(),
                      1,
                      15,
                      (v) => _save(_settings.copyWith(
                          longBreakDurationMinutes: v.round())),
                    ),
                  ]),
                  const SizedBox(height: 28),
                  _sectionHeader('PREFERENCES'),
                  const SizedBox(height: 12),
                  _buildSettingsCard([
                    _toggleRow(
                      'Enable sound',
                      _settings.soundEnabled,
                      (v) => _save(_settings.copyWith(soundEnabled: v)),
                    ),
                    _divider(),
                    _toggleRow(
                      'Launch at login',
                      _settings.autoStart,
                      (v) async {
                        _save(_settings.copyWith(autoStart: v));
                        if (v) {
                          await launchAtStartup.enable();
                        } else {
                          await launchAtStartup.disable();
                        }
                      },
                    ),
                    _divider(),
                    _toggleRow(
                      'Strict mode (cannot skip)',
                      _settings.strictMode,
                      (v) => _save(_settings.copyWith(strictMode: v)),
                    ),
                    _divider(),
                    _dropdownRow(
                      'Menu Bar Style',
                      _settings.menuBarStyle,
                      ['countdown', 'progress', 'icon'],
                      (v) {
                        _save(_settings.copyWith(menuBarStyle: v));
                        sl<TimerEngine>().updateMenuStyle(v ?? 'countdown');
                      },
                    ),
                  ]),
                  const SizedBox(height: 28),
                  _sectionHeader('STATISTICS'),
                  const SizedBox(height: 12),
                  DailyStatsChart(stats: _stats),
                  const SizedBox(height: 12),
                  _buildStatsCard(),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(title, style: AppTheme.sectionTitle),
    );
  }

  Widget _buildProfileSelector() {
    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: BreakProfile.presets.map((p) {
          final isSelected = _settings.selectedProfileId == p.id;
          return _profileRow(p, isSelected);
        }).toList(),
      ),
    );
  }

  Widget _profileRow(BreakProfile profile, bool isSelected) {
    return Column(
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            Provider.of<BreakController>(context, listen: false)
                .changeProfile(profile);
            setState(() {
              _settings = Provider.of<SettingsRepository>(context, listen: false)
                  .currentSettings;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: TextStyle(
                        fontSize: 14,
                        color: isSelected ? AppTheme.shortBreakColor : Colors.white,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    Text(
                      'Every ${profile.shortIntervalMinutes}m / ${profile.shortDurationSeconds}s',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF8E8EA0)),
                    ),
                  ],
                ),
                if (isSelected)
                  const Icon(CupertinoIcons.check_mark,
                      color: AppTheme.shortBreakColor, size: 16),
              ],
            ),
          ),
        ),
        if (profile != BreakProfile.presets.last) _divider(),
      ],
    );
  }

  Widget _dropdownRow(String label, String value, List<String> options,
      ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFFF0F0F5)),
          ),
          DropdownButton<String>(
            value: value,
            underline: const SizedBox(),
            dropdownColor: AppTheme.cardBackground,
            style: const TextStyle(fontSize: 13, color: AppTheme.shortBreakColor),
            items: options.map((o) {
              return DropdownMenuItem(value: o, child: Text(o));
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(children: children),
    );
  }

  Widget _sliderRow(
    String label,
    String valueLabel,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFFF0F0F5)),
            ),
          ),
          Expanded(
            child: CupertinoSlider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: (max - min).round(),
              activeColor: AppTheme.shortBreakColor,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              valueLabel,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF8E8EA0),
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFFF0F0F5)),
          ),
          CupertinoSwitch(
            value: value,
            activeTrackColor: AppTheme.shortBreakColor,
            onChanged: (v) => onChanged(v),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    final rate = (_stats.completionRate * 100).toStringAsFixed(0);
    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _statRow('Breaks completed', '${_stats.breaksCompleted}'),
          const SizedBox(height: 8),
          _statRow('Breaks skipped', '${_stats.breaksSkipped}'),
          const SizedBox(height: 8),
          _statRow('Completion rate', '$rate%'),
          const SizedBox(height: 8),
          _statRow('Today usage', '${_stats.dailyUsageMinutes} min'),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF8E8EA0)),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFFF0F0F5),
            fontWeight: FontWeight.w600,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return const Divider(
      height: 1,
      thickness: 0.5,
      color: Color(0xFF2A2A3A),
      indent: 16,
      endIndent: 16,
    );
  }
}
