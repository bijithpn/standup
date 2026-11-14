import 'package:flutter/material.dart';
import '../settings/settings_model.dart';
import 'timing_suggestion.dart';

Future<void> showTimingSuggestion(
  BuildContext context,
  TimingSuggestion? suggestion, {
  required SettingsModel Function() currentSettings,
  required Future<void> Function(SettingsModel) onApply,
}) async {
  if (suggestion == null) {
    await showDialog<void>(
      context: context,
      animationStyle: MediaQuery.maybeDisableAnimationsOf(context) == true
          ? AnimationStyle.noAnimation
          : null,
      builder: (context) => AlertDialog(
        title: const Text('Your current settings already cover this'),
        content: const Text(
          'You can adjust working hours, detection or your break profile in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    return;
  }
  await showDialog<void>(
    context: context,
    animationStyle: MediaQuery.maybeDisableAnimationsOf(context) == true
        ? AnimationStyle.noAnimation
        : null,
    builder: (context) => _SuggestionDialog(
      suggestion: suggestion,
      currentSettings: currentSettings,
      onApply: onApply,
    ),
  );
}

class _SuggestionDialog extends StatefulWidget {
  final TimingSuggestion suggestion;
  final SettingsModel Function() currentSettings;
  final Future<void> Function(SettingsModel) onApply;
  const _SuggestionDialog({
    required this.suggestion,
    required this.currentSettings,
    required this.onApply,
  });
  @override
  State<_SuggestionDialog> createState() => _SuggestionDialogState();
}

class _SuggestionDialogState extends State<_SuggestionDialog> {
  bool _saving = false;
  String? _error;
  Future<void> _apply() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onApply(widget.suggestion.apply(widget.currentSettings()));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save this change. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text(widget.suggestion.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.suggestion.explanation),
          const SizedBox(height: 12),
          const Text('Only applied if you choose Apply.'),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Keep current settings'),
        ),
        FilledButton(
          onPressed: _saving ? null : _apply,
          child: Text(_saving ? 'Saving…' : 'Apply'),
        ),
      ],
    ),
  );
}
