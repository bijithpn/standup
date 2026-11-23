import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_system/application/skip_policy.dart';

/// Asks why a break is being skipped; picking a reason skips, Escape or "Back to break" returns to the break.
class SkipReasonPicker extends StatefulWidget {
  final ValueChanged<String> onReason;
  final VoidCallback onCancel;

  const SkipReasonPicker({
    super.key,
    required this.onReason,
    required this.onCancel,
  });

  @override
  State<SkipReasonPicker> createState() => _SkipReasonPickerState();
}

class _SkipReasonPickerState extends State<SkipReasonPicker> {
  final _previousFocus = FocusManager.instance.primaryFocus;

  @override
  void dispose() {
    if (_previousFocus?.context?.mounted ?? false) {
      _previousFocus!.requestFocus();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onReason = widget.onReason;
    final onCancel = widget.onCancel;
    final palette = BreakPalette.of(context);
    return Positioned.fill(
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): onCancel},
        child: FocusScope(
          autofocus: true,
          child: Semantics(
            scopesRoute: true,
            explicitChildNodes: true,
            namesRoute: true,
            label: 'Why skip this break',
            child: ColoredBox(
              color: palette.canvas.withValues(alpha: 0.6),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(
                        BreakOverlayTheme.radiusMd,
                      ),
                      border: Border.all(color: palette.border),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Why skip this break?',
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final r in SkipPolicy.reasons)
                                OutlinedButton(
                                  onPressed: () => onReason(r),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 40),
                                    foregroundColor: palette.textPrimary,
                                    side: BorderSide(color: palette.border),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        BreakOverlayTheme.radiusSm,
                                      ),
                                    ),
                                  ),
                                  child: Text(r),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          FilledButton.tonal(
                            autofocus: true,
                            onPressed: onCancel,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 40),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  BreakOverlayTheme.radiusSm,
                                ),
                              ),
                            ),
                            child: const Text('Back to break'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
