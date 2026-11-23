import 'package:breakmate/shared/widgets/minimal_controls.dart';
import 'package:flutter/material.dart';
import 'package:blobatar_flutter/blobatar_flutter.dart';
import 'package:breakmate/features/companion/domain/blobatar_emotion_mapper.dart';
import 'package:breakmate/features/companion/presentation/widgets/blobatar_companion_widget.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// Dialog to rename the Blobatar; onSaved receives the new name.
Future<String?> showBlobatarNameDialog(
  BuildContext context, {
  required String currentName,
  required ValueChanged<String> onSaved,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) =>
        _BlobatarNameDialog(currentName: currentName, onSaved: onSaved),
  );
}

class _BlobatarNameDialog extends StatefulWidget {
  final String currentName;
  final ValueChanged<String> onSaved;

  const _BlobatarNameDialog({required this.currentName, required this.onSaved});

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
    _previewName = widget.currentName.trim().isEmpty
        ? 'Blobby'
        : widget.currentName;
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
      insetPadding: const EdgeInsets.all(AppTheme.space24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.all(AppTheme.space24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.border),
        ),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Name your companion',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppTheme.space8),
              Text(
                'The name sets the shape and color.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: AppTheme.space16),
              SizedBox(
                width: 128,
                height: 128,
                child: Center(
                  child: BlobatarCompanionWidget(
                    name: _previewName,
                    size: 100,
                    isInteractive: false,
                    animate: BlobatarAnimate.none,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.space16),
              TextField(
                controller: _controller,
                autofocus: true,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Name',
                  hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space16,
                    vertical: AppTheme.space12,
                  ),
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: BorderSide(color: AppTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: BorderSide(
                      color: AppTheme.accentColor,
                      width: 1.5,
                    ),
                  ),
                ),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: AppTheme.space12),
              Wrap(
                spacing: AppTheme.space8,
                runSpacing: AppTheme.space8,
                alignment: WrapAlignment.center,
                children: suggestions.map((name) {
                  final isCurrent =
                      _previewName.toLowerCase() == name.toLowerCase();
                  return ChoiceChip(
                    label: Text(name),
                    selected: isCurrent,
                    showCheckmark: false,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onSelected: (_) {
                      _controller.text = name;
                      _controller.selection = TextSelection.fromPosition(
                        TextPosition(offset: name.length),
                      );
                    },
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isCurrent
                          ? AppTheme.accentColor
                          : AppTheme.textSecondary,
                    ),
                    backgroundColor: AppTheme.surface,
                    selectedColor: AppTheme.accentColor.withValues(alpha: 0.12),
                    side: BorderSide(
                      color: isCurrent ? AppTheme.accentColor : AppTheme.border,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppTheme.space24),
              Row(
                children: [
                  Expanded(
                    child: MinimalButton(
                      isSecondary: true,
                      onPressed: () => Navigator.of(context).pop(),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.space12,
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppTheme.space12),
                  Expanded(
                    child: MinimalButton(
                      backgroundColor: AppTheme.accentColor,
                      onPressed: _save,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.space12,
                      ),
                      child: const Text('Save'),
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
