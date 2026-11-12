import 'dart:async';

import 'package:flutter/material.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

class Toast {
  static OverlayEntry? _current;
  static Timer? _timer;

  static void showError(BuildContext context, String message) => showOn(
    Overlay.of(context),
    message,
    AppTheme.error,
    Icons.error_outline_rounded,
  );

  static void showSuccess(BuildContext context, String message) => showOn(
    Overlay.of(context),
    message,
    AppTheme.success,
    Icons.check_circle_rounded,
  );

  static void showOn(
    OverlayState overlay,
    String message,
    Color tone,
    IconData icon, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _dismiss();
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
            child: Container(
              constraints: const BoxConstraints(maxWidth: 360),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
    );
    _current = entry;
    overlay.insert(entry);
    _timer = Timer(duration, _dismiss);
  }

  static void _dismiss() {
    _timer?.cancel();
    final entry = _current;
    _current = null;
    if (entry != null && entry.mounted) entry.remove();
  }
}
