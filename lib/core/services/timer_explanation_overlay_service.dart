import 'dart:async';
import 'package:flutter/material.dart';
import 'package:breakmate/core/services/error_toast_service.dart';
import 'package:breakmate/core/services/timer_explanation.dart';

/// Shows the explanation as an in-app overlay panel on the root navigator; replaces any open panel and auto-dismisses.
class TimerExplanationOverlayService {
  static const _autoDismissAfter = Duration(seconds: 20);

  static OverlayEntry? _entry;
  static Timer? _dismissTimer;

  static void show(TimerExplanation explanation) {
    dismiss();

    final context = ErrorToastService.navigatorKey.currentContext;
    if (context == null) return;
    final overlay = Navigator.of(context).overlay;
    if (overlay == null) return;

    final entry = OverlayEntry(
      builder: (context) =>
          _ExplanationPanel(explanation: explanation, onDismiss: dismiss),
    );
    _entry = entry;

    // Insert after the frame to avoid modifying the overlay during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (overlay.mounted) {
        overlay.insert(entry);
        _dismissTimer = Timer(_autoDismissAfter, dismiss);
      }
    });
  }

  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _entry?.remove();
    _entry = null;
  }
}

class _ExplanationPanel extends StatelessWidget {
  final TimerExplanation explanation;
  final VoidCallback onDismiss;

  const _ExplanationPanel({required this.explanation, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onDismiss,
          ),
        ),
        Positioned(
          top: 50,
          right: 20,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: 320,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 18,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            explanation.stateSummary,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: onDismiss,
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                    if (explanation.reasons.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      for (final reason in explanation.reasons)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '•  $reason',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                    ],
                    if (explanation.activeSmartFeatures.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Active: ${explanation.activeSmartFeatures.join(', ')}',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
