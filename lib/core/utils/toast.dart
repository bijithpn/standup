import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

class Toast {
  static OverlayEntry? _current;
  static Timer? _timer;
  static String? _message;

  static void showError(BuildContext context, String message) => showOn(
    Overlay.of(context),
    message,
    AppTheme.error,
    CupertinoIcons.exclamationmark_circle,
  );

  static void showSuccess(BuildContext context, String message) => showOn(
    Overlay.of(context),
    message,
    AppTheme.success,
    CupertinoIcons.checkmark_circle,
  );

  static void showOn(
    OverlayState overlay,
    String message,
    Color tone,
    IconData icon, {
    Duration duration = const Duration(seconds: 3),
  }) {
    // A repeating error must not keep replacing the toast and resetting its timer.
    if (_current != null && _message == message) return;
    _dismiss();
    _message = message;
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        right: 24,
        bottom: 24,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          builder: (_, t, child) => Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, 8 * (1 - t)),
              child: child,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: _dismiss,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 360),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: tone.withValues(alpha: 0.45)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: tone, size: 18),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    _current = entry;
    overlay.insert(entry);
    _timer = Timer(duration, _dismiss);
  }

  static void _dismiss() {
    _timer?.cancel();
    final entry = _current;
    _current = null;
    _message = null;
    if (entry != null && entry.mounted) entry.remove();
  }
}
