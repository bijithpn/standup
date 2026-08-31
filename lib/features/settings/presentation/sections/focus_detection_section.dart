import 'package:flutter/material.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/services/calendar_permission_service.dart';
import 'package:breakmate/core/utils/toast.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

class FocusDetectionSection extends StatefulWidget {
  final SettingsModel settings;
  final ValueChanged<SettingsModel> onSave;

  const FocusDetectionSection({
    super.key,
    required this.settings,
    required this.onSave,
  });

  @override
  State<FocusDetectionSection> createState() => _FocusDetectionSectionState();
}

class _FocusDetectionSectionState extends State<FocusDetectionSection>
    with WidgetsBindingObserver {
  CalendarPermissionStatus _permState = CalendarPermissionStatus.notDetermined;
  bool _isLoading = false;
  bool _isRequesting = false;

  SettingsModel get _settings => widget.settings;
  void _save(SettingsModel s) => widget.onSave(s);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Always check permission status on entry so the banner reflects reality.
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  @override
  void didUpdateWidget(FocusDetectionSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.settings.calendarEnabled &&
        widget.settings.calendarEnabled) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final status = await sl<CalendarPermissionService>().getStatus();
      if (mounted) {
        setState(() {
          _permState = status;
          _isLoading = false;
        });
        if (status == CalendarPermissionStatus.granted &&
            !_settings.calendarEnabled) {
          _save(
            _settings.copyWith(calendarEnabled: true, detectMeetings: true),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _permState = CalendarPermissionStatus.denied;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleMeetingDetectionToggle(bool value) async {
    _save(_settings.copyWith(detectMeetings: value, calendarEnabled: value));

    if (!value) return; // Turning off — no permission work needed.

    if (_permState == CalendarPermissionStatus.granted) return; // already OK

    await _requestCalendarAccess();
  }

  Future<void> _requestCalendarAccess() async {
    if (_isRequesting) return;

    final currentStatus = await sl<CalendarPermissionService>().getStatus();
    if (currentStatus == CalendarPermissionStatus.permanentlyDenied) {
      await sl<CalendarPermissionService>().openSettings();
      return;
    }

    if (mounted) {
      setState(() {
        _isRequesting = true;
        _isLoading = true;
      });
    }

    try {
      final granted = await sl<CalendarPermissionService>().requestPermission();

      if (!mounted) return;

      if (granted) {
        setState(() => _permState = CalendarPermissionStatus.granted);
        Toast.showSuccess(context, 'Calendar access granted!');
        _save(_settings.copyWith(calendarEnabled: true, detectMeetings: true));
      } else {
        setState(() => _permState = CalendarPermissionStatus.denied);
        Toast.showError(
          context,
          'Calendar access denied. Tap "Open Settings" to enable it.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _permState = CalendarPermissionStatus.denied);
        Toast.showError(
          context,
          'Unexpected error requesting calendar access.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRequesting = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader('Smart Detection'),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 24),
          child: Text(
            'Automatically pauses your breaks when you are busy.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ),

        buildCard([
          toggleRow(
            'Video Calls Detection',
            'Pause breaks during Zoom, Meet, Teams, etc.',
            _settings.detectVideoCalls,
            (v) => _save(_settings.copyWith(detectVideoCalls: v)),
          ),
          divider(),
          toggleRow(
            'Meeting Detection',
            'Sync with calendar to pause during meetings',
            _settings.detectMeetings,
            _handleMeetingDetectionToggle,
          ),
          if (_settings.detectMeetings || _settings.calendarEnabled)
            _buildCalendarPermissionBanner(),
          divider(),
          toggleRow(
            'Focus Mode Detection',
            'Respect macOS Do Not Disturb & Focus Modes',
            _settings.respectFocusMode,
            (v) => _save(_settings.copyWith(respectFocusMode: v)),
          ),
          divider(),
          toggleRow(
            'Presentation Pause',
            'Pause breaks while a fullscreen slideshow or presentation is showing',
            _settings.presentationPauseEnabled,
            (v) => _save(_settings.copyWith(presentationPauseEnabled: v)),
          ),
        ]),
      ],
    );
  }

  Widget _buildCalendarPermissionBanner() {
    if (_isLoading) {
      return _banner(
        color: AppTheme.accent,
        icon: Icons.hourglass_top_rounded,
        title: 'Checking calendar permission…',
        subtitle: null,
        actions: const [],
      );
    }

    switch (_permState) {
      case CalendarPermissionStatus.granted:
        return _banner(
          color: AppTheme.success,
          icon: Icons.check_circle_outline_rounded,
          title: 'Calendar access granted',
          subtitle: 'BreakMate can read your upcoming events.',
          actions: const [],
        );

      case CalendarPermissionStatus.restricted:
        return _banner(
          color: AppTheme.warning,
          icon: Icons.lock_outline_rounded,
          title: 'Calendar access restricted',
          subtitle: 'Calendar access is restricted on this device.',
          actions: [
            _BannerButton(
              label: 'Open Settings',
              color: AppTheme.textSecondary,
              onTap: () => sl<CalendarPermissionService>().openSettings(),
            ),
            const SizedBox(width: 8),
            _BannerButton(
              label: 'Refresh',
              color: AppTheme.textSecondary,
              onTap: _checkPermission,
            ),
          ],
        );

      case CalendarPermissionStatus.denied:
        return _banner(
          color: AppTheme.warning,
          icon: Icons.lock_outline_rounded,
          title: 'Calendar access denied',
          subtitle: 'Calendar access was denied. Tap "Grant Access" to request again or "Open Settings" to authorize.',
          actions: [
            _BannerButton(
              label: _isRequesting ? 'Requesting…' : 'Grant Access',
              color: const Color(0xFF6366F1),
              isLoading: _isRequesting,
              onTap: _isRequesting ? null : _requestCalendarAccess,
            ),
            const SizedBox(width: 8),
            _BannerButton(
              label: 'Open Settings',
              color: AppTheme.textSecondary,
              onTap: () => sl<CalendarPermissionService>().openSettings(),
            ),
          ],
        );

      case CalendarPermissionStatus.permanentlyDenied:
        return _banner(
          color: AppTheme.warning,
          icon: Icons.lock_outline_rounded,
          title: 'Calendar access blocked',
          subtitle: 'Calendar access is permanently blocked by the system. Please enable it in system settings.',
          actions: [
            _BannerButton(
              label: 'Open Settings',
              color: const Color(0xFF6366F1),
              onTap: () => sl<CalendarPermissionService>().openSettings(),
            ),
            const SizedBox(width: 8),
            _BannerButton(
              label: 'Refresh Status',
              color: AppTheme.textSecondary,
              onTap: _checkPermission,
            ),
          ],
        );

      case CalendarPermissionStatus.notDetermined:
        return _banner(
          color: AppTheme.warning,
          icon: Icons.lock_outline_rounded,
          title: 'Calendar access required',
          subtitle:
              'Grant access so BreakMate can see your meetings and avoid interrupting them.',
          actions: [
            _BannerButton(
              label: _isRequesting ? 'Requesting…' : 'Grant Access',
              color: const Color(0xFF6366F1),
              isLoading: _isRequesting,
              onTap: _isRequesting ? null : _requestCalendarAccess,
            ),
            const SizedBox(width: 8),
            _BannerButton(
              label: 'Open Settings',
              color: AppTheme.textSecondary,
              onTap: () => sl<CalendarPermissionService>().openSettings(),
            ),
          ],
        );
    }
  }

  Widget _banner({
    required Color color,
    required IconData icon,
    required String title,
    required String? subtitle,
    required List<Widget> actions,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: color,
                        fontFamily: 'Inter',
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          height: 1.4,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(children: actions),
          ],
        ],
      ),
    );
  }
}

class _BannerButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool isLoading;

  const _BannerButton({
    required this.label,
    required this.color,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: onTap == null ? 0.05 : 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading) ...[
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: onTap == null ? color.withValues(alpha: 0.5) : color,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
