import 'package:breakmate/features/settings/widgets/settings_group.dart';
import 'package:breakmate/features/settings/widgets/detection_health_panel.dart';
import 'package:breakmate/features/settings/widgets/status_pill.dart';
import 'package:flutter/cupertino.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/native/presentation_detection_service.dart';
import 'package:breakmate/core/services/app_navigation_service.dart';
import 'package:breakmate/core/services/smart_detection_service.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/shared/widgets/minimal_controls.dart';

/// Settings > Smart Detection: detector toggles with live state, then permission status.
class FocusDetectionSection extends StatelessWidget {
  final SettingsModel settings;
  final ValueChanged<SettingsModel> onSave;

  const FocusDetectionSection({
    super.key,
    required this.settings,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return _LiveSignals(
      builder: (context, live) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SettingsNote(
            'Adapts your breaks when you are busy, without interrupting your focus timer.',
          ),
          sectionHeader('Detectors'),
          SettingsGroup(
            children: [
              _DetectorTile(
                title: 'Video calls',
                subtitle:
                    'A small reminder instead of the full break in Zoom, Meet, Teams and similar',
                enabled: settings.detectVideoCalls,
                activeNow: live.call,
                activeLabel: 'In a call',
                onChanged: (v) =>
                    onSave(settings.copyWith(detectVideoCalls: v)),
              ),
              _DetectorTile(
                title: 'Calendar meetings',
                subtitle: settings.detectMeetings && settings.calendarEnabled
                    ? 'Breaks stay quiet during calendar events'
                    : 'Connect a calendar to keep breaks quiet during events',
                enabled: settings.detectMeetings && settings.calendarEnabled,
                activeNow: live.meeting,
                activeLabel: 'In a meeting',
                action: _TileButton(
                  'Open calendar sync',
                  () => sl<AppNavigationService>().openSection('Calendar Sync'),
                ),
              ),
              _DetectorTile(
                title: 'Presentations',
                subtitle: 'Pauses the timer during a fullscreen slideshow',
                enabled: settings.presentationPauseEnabled,
                activeNow: live.presenting,
                activeLabel: 'Presenting',
                onChanged: (v) =>
                    onSave(settings.copyWith(presentationPauseEnabled: v)),
              ),
            ],
          ),
          sectionHeader('Permissions'),
          DetectionHealthPanel(settings: settings),
        ],
      ),
    );
  }
}

class _Live {
  final bool call;
  final bool meeting;
  final bool presenting;
  final bool camera;
  final bool mic;
  final bool video;
  const _Live({
    this.call = false,
    this.meeting = false,
    this.presenting = false,
    this.camera = false,
    this.mic = false,
    this.video = false,
  });
  bool get any => call || meeting || presenting || video;
}

/// Rebuilds from the detector stream and the timer engine; services missing in tests read as "nothing detected".
class _LiveSignals extends StatelessWidget {
  final Widget Function(BuildContext, _Live) builder;
  const _LiveSignals({required this.builder});

  _Live _read() {
    final smart = sl.isRegistered<SmartDetectionService>()
        ? sl<SmartDetectionService>().currentState
        : SmartDetectionState.idle;
    final engine = sl.isRegistered<TimerEngine>() ? sl<TimerEngine>() : null;
    return _Live(
      call: smart.isInMeeting,
      meeting:
          (engine?.contextManager.isMeetingActive() ?? false) &&
          !smart.isInMeeting,
      presenting: sl.isRegistered<PresentationDetectionService>()
          ? sl<PresentationDetectionService>().isPresenting
          : false,
      camera: smart.isCameraActive,
      mic: smart.isMicrophoneActive,
      video: smart.isVideoPlaying,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget inner(BuildContext c) => builder(c, _read());
    final engine = sl.isRegistered<TimerEngine>() ? sl<TimerEngine>() : null;
    final stream = sl.isRegistered<SmartDetectionService>()
        ? sl<SmartDetectionService>().stateStream
        : null;
    Widget withStream(BuildContext c) => stream == null
        ? inner(c)
        : StreamBuilder<SmartDetectionState>(
            stream: stream,
            builder: (c, _) => inner(c),
          );
    return engine == null
        ? withStream(context)
        : ListenableBuilder(
            listenable: engine,
            builder: (c, _) => withStream(c),
          );
  }
}

class _DetectorTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool enabled;
  final bool activeNow;
  final String activeLabel;
  final ValueChanged<bool>? onChanged;
  final Widget? action;

  const _DetectorTile({
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.activeNow,
    required this.activeLabel,
    this.onChanged,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final pill = !enabled
        ? const StatusPill('Off', tone: PillTone.off)
        : activeNow
        ? StatusPill(activeLabel, tone: PillTone.active)
        : const StatusPill('Watching', tone: PillTone.ok);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    pill,
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (onChanged != null)
            Semantics(
              label: title,
              child: CupertinoSwitch(
                value: enabled,
                onChanged: onChanged,
                activeTrackColor: AppTheme.accentColor,
                inactiveTrackColor: AppTheme.border,
              ),
            )
          else
            ?action,
        ],
      ),
    );
  }
}

class _TileButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _TileButton(this.label, this.onPressed);

  @override
  Widget build(BuildContext context) => MinimalButton(
    onPressed: onPressed,
    isSecondary: true,
    child: Text(label),
  );
}
