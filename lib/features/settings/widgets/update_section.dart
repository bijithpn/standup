import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:breakmate/core/services/feed_update_checker.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/shared/widgets/minimal_controls.dart';

/// Settings > Updates: manual check via Sparkle on macOS (native channel callbacks) or the feed checker elsewhere.
class UpdateSection extends StatefulWidget {
  final SettingsModel settings;
  final ValueChanged<SettingsModel> onSave;

  const UpdateSection({
    super.key,
    required this.settings,
    required this.onSave,
  });

  @override
  State<UpdateSection> createState() => _UpdateSectionState();
}

class _UpdateSectionState extends State<UpdateSection> {
  // Sparkle reports results asynchronously through this channel (onUpdateResult / onUpdateError).
  static const _channel = MethodChannel('com.breakmate/sparkle');

  bool _isChecking = false;
  bool _checked = false;
  bool _hasUpdate = false;
  String _updateVersion = '';
  String _errorMessage = '';
  Timer? _checkTimeout;
  FeedUpdate? _feedUpdate;

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler((call) async {
      debugPrint('UpdateSection: Received method channel call: ${call.method}');
      if (call.method == 'onUpdateResult') {
        _checkTimeout?.cancel();
        final args = Map<String, dynamic>.from(call.arguments);
        final hasUpdate = args['hasUpdate'] as bool? ?? false;
        final version = args['version'] as String? ?? '';
        debugPrint(
          'UpdateSection: onUpdateResult: hasUpdate=$hasUpdate, version=$version',
        );
        if (mounted) {
          setState(() {
            _isChecking = false;
            _checked = true;
            _hasUpdate = hasUpdate;
            _updateVersion = version;
            _errorMessage = '';
          });
        }
      } else if (call.method == 'onUpdateError') {
        _checkTimeout?.cancel();
        final args = Map<String, dynamic>.from(call.arguments);
        final error = args['error'] as String? ?? 'Failed to check for updates';
        debugPrint('UpdateSection: onUpdateError: $error');
        final normalizedError = error.toLowerCase();

        String displayError = error;
        if (normalizedError.contains('signature')) {
          displayError =
              'Update validation failed (invalid signature). Please contact support.';
        } else if (normalizedError.contains('connect') ||
            normalizedError.contains('network')) {
          displayError =
              'Unable to connect to update server. Please check your internet connection.';
        }

        // Sparkle reports "already latest" as an error string, so treat those as success.
        final isUpToDate =
            normalizedError.contains('up to date') ||
            normalizedError.contains('up-to-date') ||
            normalizedError.contains('newest version') ||
            normalizedError.contains('latest version') ||
            normalizedError.contains('no update') ||
            normalizedError.contains('no updates');
        if (mounted) {
          setState(() {
            _isChecking = false;
            _checked = true;
            _hasUpdate = false;
            _errorMessage = isUpToDate ? '' : displayError;
          });
        }
      }
    });
  }

  Future<void> _checkForUpdates() async {
    debugPrint('UpdateSection: _checkForUpdates called');
    if (_isChecking) {
      debugPrint('UpdateSection: Already checking, ignoring');
      return;
    }
    setState(() {
      _isChecking = true;
      _checked = false;
      _hasUpdate = false;
      _errorMessage = '';
    });
    _checkTimeout?.cancel();
    // Guard against Sparkle never calling back.
    _checkTimeout = Timer(const Duration(seconds: 30), () {
      if (!mounted || !_isChecking) return;
      setState(() {
        _isChecking = false;
        _checked = true;
        _errorMessage =
            'The update server did not respond. Check your connection and try again.';
      });
    });
    if (!Platform.isMacOS) {
      await _checkFeed();
      return;
    }
    try {
      debugPrint('UpdateSection: Invoking checkForUpdates method channel');
      await _channel.invokeMethod('checkForUpdates', {
        'theme': {
          'background': AppTheme.surfaceElevated.toARGB32(),
          'surface': AppTheme.surfaceCard.toARGB32(),
          'border': AppTheme.border.toARGB32(),
          'foreground': AppTheme.textPrimary.toARGB32(),
          'secondary': AppTheme.textSecondary.toARGB32(),
          'accent': AppTheme.accent.toARGB32(),
          'onAccent': AppTheme.onAccent.toARGB32(),
          'isDark': AppTheme.activePreset.isDark,
        },
      });
    } catch (e) {
      _checkTimeout?.cancel();
      debugPrint('UpdateSection: Error invoking checkForUpdates: $e');
      if (mounted) {
        setState(() {
          _isChecking = false;
          _checked = true;
          _errorMessage = e is PlatformException && e.message != null
              ? e.message!
              : 'Failed to check for updates .Please try again later.${kDebugMode ? "($e)" : ''}';
        });
      }
    }
  }

  Future<void> _checkFeed() async {
    try {
      final update = await FeedUpdateChecker().check();
      _checkTimeout?.cancel();
      if (!mounted) return;
      setState(() {
        _feedUpdate = update;
        _isChecking = false;
        _checked = true;
        _hasUpdate = update != null;
        _updateVersion = update?.version ?? '';
        _errorMessage = '';
      });
    } catch (e) {
      _checkTimeout?.cancel();
      debugPrint('UpdateSection: feed check failed: $e');
      if (!mounted) return;
      setState(() {
        _isChecking = false;
        _checked = true;
        _errorMessage =
            'Unable to connect to update server. Please check your internet connection.';
      });
    }
  }

  @override
  void dispose() {
    _checkTimeout?.cancel();
    super.dispose();
  }

  Future<void> _startUpdate() async {
    debugPrint('UpdateSection: _startUpdate called');
    final feedUpdate = _feedUpdate;
    if (!Platform.isMacOS && feedUpdate != null) {
      await launchUrl(
        feedUpdate.downloadUrl,
        mode: LaunchMode.externalApplication,
      );
      return;
    }
    try {
      await _channel.invokeMethod('startUpdate');
    } catch (e) {
      debugPrint('UpdateSection: Error invoking startUpdate: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _errorMessage.isNotEmpty
        ? 'Update check failed'
        : _hasUpdate
        ? 'Version $_updateVersion available'
        : _isChecking
        ? 'Checking for updates'
        : _checked
        ? 'BreakMate is up to date'
        : 'Software update';
    final helper = _errorMessage.isNotEmpty
        ? _errorMessage
        : _hasUpdate
        ? 'Release notes appear in the update window when you install'
        : _isChecking
        ? 'Connecting to the update server'
        : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader('Software update'),
        buildCard([
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (helper.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          helper,
                          style: TextStyle(
                            fontSize: 12,
                            color: _errorMessage.isNotEmpty
                                ? AppTheme.error
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                if (_hasUpdate)
                  MinimalButton(
                    onPressed: _startUpdate,
                    backgroundColor: AppTheme.accentColor,
                    child: Text(
                      'Install and restart',
                      style: TextStyle(
                        color: AppTheme.onAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                else if (_isChecking)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  MinimalButton(
                    onPressed: _checkForUpdates,
                    isSecondary: true,
                    child: const Text('Check now'),
                  ),
              ],
            ),
          ),
        ]),
      ],
    );
  }
}
