import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';
import 'package:standup/features/break_system/application/break_controller.dart';
import 'package:standup/features/settings/settings_model.dart';
import 'package:standup/features/settings/settings_repository.dart';
import 'package:standup/features/statistics/stats_model.dart';
import 'package:standup/features/statistics/stats_service.dart';
import 'package:standup/features/settings/break_profile.dart';
import 'package:standup/features/statistics/widgets/stats_chart.dart';
import 'package:standup/ui/theme/app_theme.dart';

class SettingsPage extends StatefulWidget {
  final String section;
  const SettingsPage({super.key, required this.section});

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
      backgroundColor: AppTheme.contentBackground,
      toolBar: ToolBar(
        title: Text(widget.section),
        titleWidth: 200,
        // backgroundColor: AppTheme.contentBackground,
        actions: [
          if (widget.section == 'Flash Reminder')
            ToolBarIconButton(
              icon: const MacosIcon(CupertinoIcons.play_fill, size: 14),
              label: 'Play demo',
              showLabel: true,
              onPressed: () {},
            ),
        ],
      ),
      children: [
        ContentArea(
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(32),
              child: _buildContent(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildContent() {
    switch (widget.section) {
      case 'General':
        return _buildGeneral();
      case 'Breaks':
        return _buildBreaks();
      case 'Flash Reminder':
        return _buildFlashReminder();
      case 'Focus Mode':
        return _buildFocusMode();
      case 'Profiles':
        return _buildProfiles();
      case 'Notifications':
        return _buildNotifications();
      case 'Exercises':
        return _buildExercises();
      case 'Clock Out':
        return _buildClockOut();
      case 'About':
        return _buildAbout();
      case 'Statistics':
        return _buildStatistics();
      default:
        return Center(
          child: Text(
            'Coming soon: ${widget.section}',
            style: AppTheme.tipStyle,
          ),
        );
    }
  }

  Widget _buildGeneral() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('App Launch'),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 2.2,
          children: [
            _buildGridCard(
              'Startup',
              'Run at login',
              _settings.autoStart,
              CupertinoIcons.rocket,
              (v) async {
                _save(_settings.copyWith(autoStart: v));
                if (v) await launchAtStartup.enable();
                else await launchAtStartup.disable();
              },
            ),
            _buildGridCard(
              'Menu Style',
              'Custom tray look',
              null,
              CupertinoIcons.macwindow,
              null,
              trailing: _inlineDropdown(_settings.menuBarStyle, ['countdown', 'progress', 'icon', 'focusdot'], (v) {
                _save(_settings.copyWith(menuBarStyle: v ?? 'countdown'));
              }),
            ),
            _buildGridCard(
              'Strict Mode',
              'No skipping',
              _settings.strictMode,
              CupertinoIcons.lock_shield,
              (v) => _save(_settings.copyWith(strictMode: v)),
            ),
            _buildGridCard(
              'Multi-Display',
              'All screens',
              true,
              CupertinoIcons.tv,
              (v) {},
            ),
          ],
        ),
        const SizedBox(height: 32),
        _sectionHeader('Idle & Inactivity'),
        const SizedBox(height: 16),
        _buildCard([
          _inputRow(
            'Pause timer after',
            '${_settings.pauseTimerAfterMinutes} min',
          ),
          _divider(),
          _inputRow(
            'Reset timer after',
            '${_settings.resetTimerAfterMinutes} min',
          ),
        ]),
        const SizedBox(height: 32),
        _sectionHeader('Working Hours'),
        const SizedBox(height: 16),
        _buildCard([
          _toggleRow(
            'Working Hours',
            'Specify on which days and at what time you want to use the app.',
            _settings.workingHoursEnabled,
            (v) => _save(_settings.copyWith(workingHoursEnabled: v)),
          ),
          if (_settings.workingHoursEnabled) ...[
            _divider(),
            _buildDaysToggle(),
            _divider(),
            _buildTimeSelector('Start Time', '09:00'),
            _divider(),
            _buildTimeSelector('End Time', '18:00'),
          ],
        ]),
      ],
    );
  }

  Widget _buildDaysToggle() {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: days.asMap().entries.map((e) {
          final isWeekend = e.key > 4;
          return Column(
            children: [
              Text(e.value, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              const SizedBox(height: 4),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isWeekend ? AppTheme.contentBackground : AppTheme.accentColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: isWeekend ? AppTheme.borderColor : AppTheme.accentColor),
                ),
                child: Center(
                  child: Icon(
                    CupertinoIcons.checkmark,
                    size: 14,
                    color: isWeekend ? AppTheme.textMuted : AppTheme.accentColor,
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimeSelector(String label, String time) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {},
            child: Text(time, style: const TextStyle(color: AppTheme.accentColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildBreaks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Clock Styles'),
        const SizedBox(height: 16),
        _buildStyleGrid(),
        const SizedBox(height: 32),
        _sectionHeader('Appearance Settings'),
        const Text(
          'Fine-tune your break experience with color and visual effects.',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        _buildCard([
          _colorRow('Text Color', Color(_settings.clockFaceTextColorHex)),
          _divider(),
          _toggleRow(
            'Background Blur',
            'Apply blur effect to the background',
            _settings.clockFaceBlurEnabled,
            (v) => _save(_settings.copyWith(clockFaceBlurEnabled: v)),
          ),
        ]),
        const SizedBox(height: 32),
        _sectionHeader('Quick Preset'),
        const Text(
          'Choose a predefined break schedule.',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        _buildProfileSelector(),
      ],
    );
  }

  Widget _buildFocusMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCard([
          _toggleRow(
            'Enable Focus Mode',
            'Automatically block notifications during work',
            _settings.focusModeEnabled,
            (v) => _save(_settings.copyWith(focusModeEnabled: v)),
          ),
          _divider(),
          _toggleRow(
            'DND Integration',
            'Sync with macOS Do Not Disturb',
            false,
            (v) {},
          ),
        ]),
        const SizedBox(height: 32),
        _sectionHeader('Focus Goals'),
        const Text(
          'Set a daily target for focused deep work.',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        _buildCard([
          _inputRow('Daily Goal', '4 hours'),
          _divider(),
          _inputRow('Session Length', '25 min'),
        ]),
      ],
    );
  }

  Widget _buildProfiles() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProfileSelector(),
        const SizedBox(height: 32),
        _sectionHeader('Create New Profile'),
        const SizedBox(height: 16),
        CupertinoButton(
          color: AppTheme.accentColor.withOpacity(0.1),
          padding: const EdgeInsets.all(16),
          borderRadius: BorderRadius.circular(12),
          onPressed: () {},
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.add, color: AppTheme.accentColor, size: 20),
              const SizedBox(width: 8),
              Text('Add Custom Profile', style: TextStyle(color: AppTheme.accentColor, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotifications() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCard([
          _toggleRow(
            'Sound Effects',
            'Play a soft chime when break starts',
            _settings.soundEnabled,
            (v) => _save(_settings.copyWith(soundEnabled: v)),
          ),
          _divider(),
          _toggleRow(
            'Repeated Alerts',
            'Notify every 30 seconds if break is ignored',
            true,
            (v) {},
          ),
          _divider(),
          _toggleRow(
            'Dock Bounce',
            'Bounce the app icon on break start',
            false,
            (v) {},
          ),
        ]),
      ],
    );
  }

  Widget _buildExercises() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Wellness Exercises'),
        const Text(
          'Scientific routines to keep you fresh during work.',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        _buildCard([
          _exerciseItem('Eye Care', '20-20-20 rule to reduce strain', CupertinoIcons.eye),
          _divider(),
          _exerciseItem('Posture Correction', 'Spine alignment and neck stretch', CupertinoIcons.person),
          _divider(),
          _exerciseItem('Mindfulness', 'Brief breathing meditation', CupertinoIcons.wind),
        ]),
        const SizedBox(height: 32),
        _sectionHeader('Smart Suggestions'),
        const SizedBox(height: 16),
        _buildCard([
          _toggleRow('Auto-suggest exercises', 'Based on your break type', true, (v) {}),
        ]),
      ],
    );
  }

  Widget _exerciseItem(String title, String subtitle, IconData icon) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppTheme.accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: AppTheme.accentColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ],
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {},
            child: const Text('Try', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildClockOut() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Clock Out Goal'),
        const Text(
          'Set your target working time for the day.',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        _buildCard([
          _inputRow('Daily Work Goal', '8 hours'),
          _divider(),
          _toggleRow('Remind to clock out', 'When goal is reached', true, (v) {}),
        ]),
        const SizedBox(height: 32),
        _sectionHeader('After-Work Routine'),
        const Text(
          'Prepare your mind for rest after the day is over.',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        _buildCard([
          _toggleRow('Digital Detox Mode', 'Disable computer notifications after 6 PM', false, (v) {}),
        ]),
      ],
    );
  }

  Widget _buildAbout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.accentColor, AppTheme.accentColor.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: AppTheme.accentColor.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: const Center(child: Icon(CupertinoIcons.infinite, color: Colors.white, size: 40)),
        ),
        const SizedBox(height: 24),
        const Text(
          'BreakMate',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const Text(
          'Version 1.2.0',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
        ),
        const SizedBox(height: 40),
        _buildCard([
          _listTile('Website', CupertinoIcons.globe, () {}),
          _divider(),
          _listTile('Support', CupertinoIcons.question_circle, () {}),
          _divider(),
          _listTile('Privacy Policy', CupertinoIcons.lock_shield, () {}),
        ]),
        const SizedBox(height: 40),
        const Text(
          'Made with ❤️ for a healthier workspace',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _listTile(String title, IconData icon, VoidCallback onTap) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.white70),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14))),
            const Icon(CupertinoIcons.chevron_right, size: 14, color: Colors.white24),
          ],
        ),
      ),
    );
  }

  Widget _buildFlashReminder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Flash Color'),
        const Text(
          'Choose the color that will grab your attention',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        _buildCard([_flashColorPicker()]),
        const SizedBox(height: 32),
        _sectionHeader('Choose Your Flash Style'),
        const Text(
          'Select from our curated flash reminder styles to match your preference.',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _stylePreview(
              'Default',
              _settings.flashStyle == 'default',
              () => _save(_settings.copyWith(flashStyle: 'default')),
            ),
            const SizedBox(width: 16),
            _stylePreview(
              'Photo Flash',
              _settings.flashStyle == 'photo',
              () => _save(_settings.copyWith(flashStyle: 'photo')),
            ),
          ],
        ),
        const SizedBox(height: 32),
        _sectionHeader('Flash Animation'),
        const Text(
          'Choose how the alert should grab your attention.',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        _buildCard([
          _dropdownRow('Animation Type', _settings.flashAnimationType, ['pulse', 'glow', 'fade', 'dim', 'edge'], (v) {
            if (v != null) _save(_settings.copyWith(flashAnimationType: v));
          }),
          _divider(),
          _sliderRow('Intensity', _settings.flashIntensity, (v) => _save(_settings.copyWith(flashIntensity: v))),
          _divider(),
          _sliderRow('Duration (s)', _settings.flashDurationMs / 1000, (v) => _save(_settings.copyWith(flashDurationMs: (v * 1000).toInt()))),
          _divider(),
          _textFieldRow('Custom Message', _settings.flashMessage, (v) => _save(_settings.copyWith(flashMessage: v))),
        ]),
      ],
    );
  }

  Widget _buildStatistics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Daily Progress'),
        const SizedBox(height: 16),
        DailyStatsChart(stats: _stats),
        const SizedBox(height: 32),
        _buildStatsCard(),
      ],
    );
  }

  // Helper Widgets
  Widget _sectionHeader(String title) {
    return Text(title, style: AppTheme.headerStyle.copyWith(fontSize: 18));
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: AppTheme.cardDecoration,
      child: Column(children: children),
    );
  }

  Widget _sliderRow(String label, double value, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
          SizedBox(
            width: 200,
            child: CupertinoSlider(
              value: value,
              onChanged: onChanged,
              activeColor: AppTheme.accentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdownRow(String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: AppTheme.contentBackground,
            borderRadius: BorderRadius.circular(6),
            onPressed: () {
              showCupertinoModalPopup(
                context: context,
                builder: (BuildContext context) => CupertinoActionSheet(
                  actions: options.map((o) => CupertinoActionSheetAction(
                    onPressed: () {
                      onChanged(o);
                      Navigator.pop(context);
                    },
                    child: Text(o),
                  )).toList(),
                  cancelButton: CupertinoActionSheetAction(
                    onPressed: () => Navigator.pop(context),
                    isDefaultAction: true,
                    child: const Text('Cancel'),
                  ),
                ),
              );
            },
            child: Text(
              value.toUpperCase(),
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleRow(
    String label,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeColor: AppTheme.accentColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _inputRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.contentBackground,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Text(
              value,
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridCard(
    String label,
    String subtitle,
    bool? value,
    IconData icon,
    ValueChanged<bool>? onChanged, {
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
              ],
            ),
          ),
          if (value != null)
            CupertinoSwitch(
              value: value,
              onChanged: onChanged,
              activeColor: AppTheme.accentColor,
            )
          else if (trailing != null)
            trailing,
        ],
      ),
    );
  }

  Widget _inlineDropdown(String value, List<String> options, ValueChanged<String?> onChanged) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        showCupertinoModalPopup(
          context: context,
          builder: (BuildContext context) => CupertinoActionSheet(
            actions: options.map((o) => CupertinoActionSheetAction(
              onPressed: () {
                onChanged(o);
                Navigator.pop(context);
              },
              child: Text(o),
            )).toList(),
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context),
              isDefaultAction: true,
              child: const Text('Cancel'),
            ),
          ),
        );
      },
      child: Text(
        value.toUpperCase(),
        style: const TextStyle(color: AppTheme.accentColor, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _textFieldRow(String label, String value, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 20),
          Expanded(
            child: CupertinoTextField(
              placeholder: value,
              placeholderStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: BoxDecoration(
                color: AppTheme.contentBackground,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.borderColor),
              ),
              onSubmitted: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorRow(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Container(
            width: 40,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _flashColorPicker() {
    final colors = [
      0xFFEF4444,
      0xFFF59E0B,
      0xFFEAB308,
      0xFF22C55E,
      0xFF3B82F6,
      0xFF8B5CF6,
      0xFFEC4899,
      0xFF6B7280,
      0xFF000000,
    ];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: colors.map((c) {
          final isSelected = _settings.flashColorHex == c;
          return GestureDetector(
            onTap: () => _save(_settings.copyWith(flashColorHex: c)),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Color(c),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _stylePreview(String name, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 140,
            height: 90,
            decoration: BoxDecoration(
              color: AppTheme.contentBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AppTheme.accentColor : AppTheme.borderColor,
                width: 2,
              ),
            ),
            child: Stack(
              children: [
                _buildStyleMock(name),
                if (isSelected)
                  const Center(
                    child: Icon(Icons.check_circle, color: AppTheme.accentColor, size: 28),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: TextStyle(
              color: isSelected ? AppTheme.accentColor : AppTheme.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyleMock(String name) {
    switch (name) {
      case 'BreakLoop':
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.shortBreakColor.withOpacity(0.5), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 4),
              const Text('00:20', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70)),
            ],
          ),
        );
      case 'Desktop':
        return Column(
          children: [
            const Spacer(),
            Container(width: 60, height: 20, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4))),
            const Spacer(),
            Container(height: 10, color: Colors.white.withOpacity(0.05)),
          ],
        );
      case 'Ambient':
        return Center(
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.accentColor.withOpacity(0.3), width: 3),
            ),
            child: const Center(child: Text('12:00', style: TextStyle(fontSize: 10, color: Colors.white30))),
          ),
        );
      case 'Focus':
        return Center(
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppTheme.accentColor.withOpacity(0.5), blurRadius: 10)],
            ),
          ),
        );
      case 'Default': // Flash Style
        return Center(child: Container(width: 100, height: 60, color: Colors.red.withOpacity(0.1)));
      case 'Photo Flash':
        return const Center(child: Icon(CupertinoIcons.photo, color: Colors.white12, size: 30));
      default:
        return const SizedBox();
    }
  }

  Widget _buildStyleGrid() {
    return Row(
      children: [
        _stylePreview(
          'BreakLoop',
          _settings.clockFaceStyle == 'breakloop',
          () => _save(_settings.copyWith(clockFaceStyle: 'breakloop')),
        ),
        const SizedBox(width: 16),
        _stylePreview(
          'Desktop',
          _settings.clockFaceStyle == 'desktop',
          () => _save(_settings.copyWith(clockFaceStyle: 'desktop')),
        ),
        const SizedBox(width: 16),
        _stylePreview(
          'Personal',
          _settings.clockFaceStyle == 'personal',
          () => _save(_settings.copyWith(clockFaceStyle: 'personal')),
        ),
        const SizedBox(width: 16),
        _stylePreview(
          'Ambient',
          _settings.clockFaceStyle == 'ambient',
          () => _save(_settings.copyWith(clockFaceStyle: 'ambient')),
        ),
        const SizedBox(width: 16),
        _stylePreview(
          'Focus',
          _settings.clockFaceStyle == 'focus',
          () => _save(_settings.copyWith(clockFaceStyle: 'focus')),
        ),
      ],
    );
  }

  Widget _buildProfileSelector() {
    return _buildCard(
      BreakProfile.presets.map((p) {
        final isSelected = _settings.selectedProfileId == p.id;
        return Column(
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                Provider.of<BreakController>(
                  context,
                  listen: false,
                ).changeProfile(p);
                setState(
                  () => _settings = Provider.of<SettingsRepository>(
                    context,
                    listen: false,
                  ).currentSettings,
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: TextStyle(
                              color: isSelected
                                  ? AppTheme.shortBreakColor
                                  : Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Every ${p.shortIntervalMinutes}m / ${p.shortDurationSeconds}s',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        CupertinoIcons.check_mark,
                        color: AppTheme.shortBreakColor,
                        size: 16,
                      ),
                  ],
                ),
              ),
            ),
            if (p != BreakProfile.presets.last) _divider(),
          ],
        );
      }).toList(),
    );
  }

  Widget _divider() =>
      Divider(height: 1, thickness: 1, color: AppTheme.borderColor);

  Widget _buildStatsCard() {
    final rate = (_stats.completionRate * 100).toStringAsFixed(0);
    return _buildCard([
      _statRow('Breaks completed', '${_stats.breaksCompleted}'),
      _divider(),
      _statRow('Breaks skipped', '${_stats.breaksSkipped}'),
      _divider(),
      _statRow('Completion rate', '$rate%'),
      _divider(),
      _statRow('Today usage', '${_stats.dailyUsageMinutes} min'),
    ]);
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
