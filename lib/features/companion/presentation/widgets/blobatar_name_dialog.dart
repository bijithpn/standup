import 'package:flutter/material.dart';
import 'package:blobatar_flutter/blobatar_flutter.dart';
import 'package:breakmate/features/companion/domain/blobatar_emotion_mapper.dart';
import 'package:breakmate/features/companion/presentation/widgets/blobatar_companion_widget.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// Shows a dialog allowing the user to rename their Blobatar companion,
/// updating the generative silhouette and colors live as they type.
Future<String?> showBlobatarNameDialog(
  BuildContext context, {
  required String currentName,
  required ValueChanged<String> onSaved,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _BlobatarNameDialog(
      currentName: currentName,
      onSaved: onSaved,
    ),
  );
}

class _BlobatarNameDialog extends StatefulWidget {
  final String currentName;
  final ValueChanged<String> onSaved;

  const _BlobatarNameDialog({
    required this.currentName,
    required this.onSaved,
  });

  @override
  State<_BlobatarNameDialog> createState() => _BlobatarNameDialogState();
}

class _BlobatarNameDialogState extends State<_BlobatarNameDialog> {
  late final TextEditingController _controller;
  late String _previewName;

  static const List<String> suggestions = [
    'Bubbles',
    'Mochi',
    'Cosmo',
    'Ziggy',
    'Pebble',
    'Pixel',
    'Noodle',
    'Pip',
  ];

  @override
  void initState() {
    super.initState();
    _previewName = widget.currentName.trim().isEmpty ? 'Blobby' : widget.currentName;
    _controller = TextEditingController(text: widget.currentName);
    _controller.addListener(() {
      final text = _controller.text;
      setState(() {
        _previewName = text.trim().isEmpty ? 'Blobby' : text;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final clean = BlobatarEmotionMapper.sanitizePetName(_controller.text);
    widget.onSaved(clean);
    Navigator.of(context).pop(clean);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppTheme.accentColor.withValues(alpha: 0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
            // Title
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: AppTheme.accentColor,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Name your Blobatar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Each unique name generates a distinct shape and color!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 18),

            // Live Blobatar Preview
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                color: AppTheme.surface.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.border),
              ),
              child: Center(
                child: BlobatarCompanionWidget(
                  name: _previewName,
                  size: 100,
                  isInteractive: false,
                  animate: BlobatarAnimate.hover,
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Text Field
            TextField(
              controller: _controller,
              autofocus: true,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Enter companion name...',
                hintStyle: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.accentColor,
                    width: 1.5,
                  ),
                ),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),

            // Suggestions Wrap
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: suggestions.map((name) {
                final isCurrent = _previewName.toLowerCase() == name.toLowerCase();
                return GestureDetector(
                  onTap: () {
                    _controller.text = name;
                    _controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: name.length),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? AppTheme.accentColor.withValues(alpha: 0.25)
                          : AppTheme.surface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCurrent
                            ? AppTheme.accentColor
                            : AppTheme.border.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                        color: isCurrent
                            ? AppTheme.accentColor
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: BorderSide(color: AppTheme.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save Name',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
          ),
        ),
      ),
    );
  }
}
