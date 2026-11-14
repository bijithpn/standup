import 'package:breakmate/features/settings/widgets/settings_group.dart';
import 'package:breakmate/features/settings/widgets/detection_health_panel.dart';
import 'package:breakmate/features/settings/widgets/status_pill.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/native/presentation_detection_service.dart';
import 'package:breakmate/core/services/app_navigation_service.dart';
import 'package:breakmate/core/services/smart_detection_service.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

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
          sectionHeader('Smart Detection'),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 20),
            child: Text(
              'Adapts your breaks when you are busy, without interrupting your focus timer.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
          // _StatusCard(settings: settings, live: live),
          const SizedBox(height: 32),
          const _GroupLabel('Detectors'),
          SettingsGroup(
            margin: const EdgeInsets.only(bottom: 32),
            children: [
              _DetectorTile(
                icon: CupertinoIcons.videocam,
                title: 'Video calls',
                subtitle:
                    'Show a small reminder instead of the full break during Zoom, Meet, Teams and similar apps.',
                enabled: settings.detectVideoCalls,
                activeNow: live.call,
                activeLabel: 'In a call',
                onChanged: (v) =>
                    onSave(settings.copyWith(detectVideoCalls: v)),
              ),
              _DetectorTile(
                icon: CupertinoIcons.calendar,
                title: 'Calendar meetings',
                subtitle: settings.detectMeetings && settings.calendarEnabled
                    ? 'Breaks stay quiet during events on your calendar.'
                    : 'Connect a calendar to keep breaks quiet during events.',
                enabled: settings.detectMeetings && settings.calendarEnabled,
                activeNow: live.meeting,
                activeLabel: 'In a meeting',
                action: _TileButton(
                  'Open Calendar Sync',
                  () => sl<AppNavigationService>().openSection('Calendar Sync'),
                ),
              ),
              _DetectorTile(
                icon: CupertinoIcons.tv,
                title: 'Presentations',
                subtitle:
                    'Pause the timer while a fullscreen slideshow is showing.',
                enabled: settings.presentationPauseEnabled,
                activeNow: live.presenting,
                activeLabel: 'Presenting',
                onChanged: (v) =>
                    onSave(settings.copyWith(presentationPauseEnabled: v)),
              ),
            ],
          ),
          const _GroupLabel('Permissions'),
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

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 12),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppTheme.textPrimary,
      ),
    ),
  );
}

class _StatusCard extends StatelessWidget {
  final SettingsModel settings;
  final _Live live;
  const _StatusCard({required this.settings, required this.live});

  @override
  Widget build(BuildContext context) {
    final anyEnabled =
        settings.detectVideoCalls ||
        (settings.detectMeetings && settings.calendarEnabled) ||
        settings.presentationPauseEnabled;
    final (tone, title, body) = !anyEnabled
        ? (
            PillTone.off,
            'Detection is off',
            'Turn on a detector below and breaks will adapt when you are busy.',
          )
        : live.presenting
        ? (
            PillTone.active,
            'Presenting: timer paused',
            'The timer resumes when the slideshow ends.',
          )
        : live.any
        ? (
            PillTone.active,
            'Quiet mode is on',
            'Breaks show a small reminder instead of the full screen until this ends.',
          )
        : (
            PillTone.ok,
            'Watching, nothing detected',
            'Your breaks will appear normally.',
          );
    final color = StatusPill.colorFor(tone);
    final signals = <(String, bool)>[
      ('Call', live.call),
      ('Meeting', live.meeting),
      ('Camera', live.camera),
      ('Microphone', live.mic),
      ('Video', live.video),
      ('Presentation', live.presenting),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: true,
            child: Row(
              children: [
                Icon(
                  anyEnabled
                      ? (live.any
                            ? CupertinoIcons.bell_slash_fill
                            : CupertinoIcons.eye_fill)
                      : CupertinoIcons.eye_slash,
                  color: color,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (anyEnabled) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (name, on) in signals)
                  StatusPill(name, tone: on ? PillTone.active : PillTone.off),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DetectorTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final bool activeNow;
  final String activeLabel;
  final ValueChanged<bool>? onChanged;
  final Widget? action;

  const _DetectorTile({
    required this.icon,
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
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    pill,
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (action != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: action,
                  ),
              ],
            ),
          ),
          if (onChanged != null) ...[
            const SizedBox(width: 16),
            Semantics(
              label: title,
              child: CupertinoSwitch(
                value: enabled,
                onChanged: onChanged,
                activeTrackColor: AppTheme.accentColor,
                inactiveTrackColor: AppTheme.border,
              ),
            ),
          ],
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
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      foregroundColor: AppTheme.accentColor,
      side: BorderSide(color: AppTheme.accentColor.withValues(alpha: 0.5)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
  );
}
