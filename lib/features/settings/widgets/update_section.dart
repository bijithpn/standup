import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/shared/widgets/minimal_controls.dart';

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
  static const _channel = MethodChannel('com.breakmate/sparkle');

  bool _isChecking = false;
  bool _checked = false;
  bool _hasUpdate = false;
  String _updateVersion = '';
  String _updateNotes = '';
  String _errorMessage = '';
  Timer? _checkTimeout;

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
        final notes = args['notes'] as String? ?? '';
        debugPrint(
          'UpdateSection: onUpdateResult: hasUpdate=$hasUpdate, version=$version',
        );
        if (mounted) {
          setState(() {
            _isChecking = false;
            _checked = true;
            _hasUpdate = hasUpdate;
            _updateVersion = version;
            _updateNotes = notes;
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
    _checkTimeout = Timer(const Duration(seconds: 30), () {
      if (!mounted || !_isChecking) return;
      setState(() {
        _isChecking = false;
        _checked = true;
        _errorMessage =
            'The update server did not respond. Check your connection and try again.';
      });
    });
    try {
      debugPrint('UpdateSection: Invoking checkForUpdates method channel');
      await _channel.invokeMethod('checkForUpdates');
    } catch (e) {
      _checkTimeout?.cancel();
      debugPrint('UpdateSection: Error invoking checkForUpdates: $e');
      if (mounted) {
        setState(() {
          _isChecking = false;
          _checked = true;
          _errorMessage = e is PlatformException && e.message != null
              ? e.message!
              : 'Failed to check for updates';
        });
      }
    }
  }

  @override
  void dispose() {
    _checkTimeout?.cancel();
    super.dispose();
  }

  Future<void> _startUpdate() async {
    debugPrint('UpdateSection: _startUpdate called');
    try {
      await _channel.invokeMethod('startUpdate');
    } catch (e) {
      debugPrint('UpdateSection: Error invoking startUpdate: $e');
    }
  }

  String _formatReleaseNotes(String rawNotes) {
    if (rawNotes.isEmpty) return 'No release notes available.';

    String notes = rawNotes
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");

    String html = md.markdownToHtml(
      notes,
      extensionSet: md.ExtensionSet.gitHubFlavored,
    );

    // 3. SURGICAL FIX: Restore the HTML tags that the markdown parser escaped.
    html = html.replaceAll(RegExp(r'&lt;(/?[a-z0-9]+.*?)&gt;'), r'<$1>');

    return html;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader('Software Update'),
        const SizedBox(height: 8),

        buildCard([
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getStatusColor().withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        _getStatusIcon(),
                        color: _getStatusColor(),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _errorMessage.isNotEmpty
                                ? 'Update Check Failed'
                                : (_hasUpdate
                                      ? 'Version $_updateVersion Available'
                                      : (_isChecking
                                            ? 'Checking for Updates...'
                                            : (_checked
                                                  ? 'BreakMate is Up to Date'
                                                  : 'Software Update'))),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                              fontFamily: 'Inter',
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _errorMessage.isNotEmpty
                                ? 'An error occurred while connecting to the server.'
                                : (_hasUpdate
                                      ? 'A newer version is ready to be installed.'
                                      : (_isChecking
                                            ? 'Connecting to update server...'
                                            : (_checked
                                                  ? 'Everything is running smoothly.'
                                                  : 'Keep your app modern and stable.'))),
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_isChecking && !_hasUpdate)
                      MinimalButton(
                        onPressed: _checkForUpdates,
                        isSecondary: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        child: const Text(
                          'Check Now',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else if (_isChecking)
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.accentColor,
                          ),
                        ),
                      ),
                  ],
                ),

                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ],

                if (_hasUpdate) ...[
                  Padding(
                    padding: EdgeInsets.only(top: 32, bottom: 12),
                    child: Text(
                      'RELEASE NOTES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textSecondary,
                        letterSpacing: 1.5,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: HtmlWidget(
                        _formatReleaseNotes(_updateNotes),
                        textStyle: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                          fontFamily: 'Inter',
                          height: 1.6,
                        ),
                        customStylesBuilder: (element) {
                          if (element.localName == 'h3' ||
                              element.localName == 'h2') {
                            return {
                              'font-weight': 'bold',
                              'font-size': '18px',
                              'margin-bottom': '12px',
                              'margin-top': '8px',
                              'color': '#ffffff',
                            };
                          }
                          if (element.localName == 'li') {
                            return {
                              'margin-bottom': '8px',
                              'line-height': '1.5',
                            };
                          }
                          if (element.localName == 'p') {
                            return {'margin-bottom': '16px'};
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: MinimalButton(
                      onPressed: _startUpdate,
                      backgroundColor: AppTheme.accentColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      borderRadius: BorderRadius.circular(14),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.arrow_down_doc_fill,
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Install and Restart Now',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ]),
        const SizedBox(height: 32),
      ],
    );
  }

  Color _getStatusColor() {
    if (_errorMessage.isNotEmpty) {
      return Colors.redAccent;
    }
    if (_hasUpdate) {
      return AppTheme.accentColor;
    }
    if (_checked && !_hasUpdate) {
      return AppTheme.success;
    }
    return AppTheme.accentColor;
  }

  IconData _getStatusIcon() {
    if (_errorMessage.isNotEmpty) {
      return CupertinoIcons.exclamationmark_triangle_fill;
    }
    if (_hasUpdate) {
      return CupertinoIcons.arrow_down_circle_fill;
    }
    if (_checked && !_hasUpdate) {
      return CupertinoIcons.checkmark_seal_fill;
    }
    return CupertinoIcons.arrow_2_circlepath;
  }
}
