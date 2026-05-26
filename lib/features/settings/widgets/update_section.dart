import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

class UpdateSection extends StatefulWidget {
  final SettingsModel settings;
  final ValueChanged<SettingsModel> onSave;

  const UpdateSection({super.key, required this.settings, required this.onSave});

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

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onUpdateResult') {
        final args = Map<String, dynamic>.from(call.arguments);
        final hasUpdate = args['hasUpdate'] as bool? ?? false;
        final version = args['version'] as String? ?? '';
        final notes = args['notes'] as String? ?? '';
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
        final args = Map<String, dynamic>.from(call.arguments);
        final error = args['error'] as String? ?? 'Failed to check for updates';
        final normalizedError = error.toLowerCase();
        
        String displayError = error;
        if (normalizedError.contains('signature')) {
          displayError = 'Update validation failed (invalid signature). Please contact support.';
        } else if (normalizedError.contains('connect') || normalizedError.contains('network')) {
          displayError = 'Unable to connect to update server. Please check your internet connection.';
        }

        final isUpToDate = normalizedError.contains('up to date') || 
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
    
    // Automatically trigger a background check when entering the update section
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
    });
  }

  Future<void> _checkForUpdates() async {
    if (_isChecking) return;
    setState(() {
      _isChecking = true;
      _checked = false;
      _hasUpdate = false;
      _errorMessage = '';
    });
    try {
      await _channel.invokeMethod('checkForUpdates');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isChecking = false;
          _checked = true;
          _errorMessage = 'Failed to check for updates';
        });
      }
    }
  }

  Future<void> _startUpdate() async {
    try {
      await _channel.invokeMethod('startUpdate');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Styled section header and visual top area
        sectionHeader('Software Update'),
        const SizedBox(height: 8),
        
        buildCard([
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Premium animated/styled state icon
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _getStatusColor().withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getStatusIcon(),
                        color: _getStatusColor(),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
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
                                        ? 'Checking for updates...'
                                        : (_checked ? 'BreakMate is up to date' : 'Check for Updates'))),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                              fontFamily: 'Satoshi',
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _errorMessage.isNotEmpty
                                ? 'An error occurred while connecting to the updates server.'
                                : (_hasUpdate
                                    ? 'A new version of BreakMate is ready to be installed.'
                                    : (_isChecking
                                        ? 'Connecting to the updates server...'
                                        : (_checked
                                            ? 'Last checked: Just now'
                                            : 'Ensure you have the latest features and fixes.'))),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontFamily: 'Satoshi',
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_isChecking && !_hasUpdate)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                        ),
                        onPressed: _checkForUpdates,
                        child: const Text(
                          'Check Now',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Satoshi',
                          ),
                        ),
                      )
                    else if (_isChecking)
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentColor),
                        ),
                      )
                  ],
                ),
                
                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.1)),
                    ),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontFamily: 'Satoshi',
                      ),
                    ),
                  ),
                ],
                
                if (_hasUpdate) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Release Notes & Changes',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: SingleChildScrollView(
                      child: Text(
                        _updateNotes,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontFamily: 'Satoshi',
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: _startUpdate,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppTheme.accentColor, const Color(0xFFFF7E5F)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accentColor.withValues(alpha: 0.25),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.arrow_down_doc_fill,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Install Update Now',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Satoshi',
                              ),
                            ),
                          ],
                        ),
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
