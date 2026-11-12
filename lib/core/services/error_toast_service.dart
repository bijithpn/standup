import 'package:flutter/material.dart';
import 'package:breakmate/core/utils/toast.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

class ErrorToastService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static void showError(String message) =>
      _show(message, AppTheme.error, Icons.error_outline_rounded, 3500);

  static void showInfo(String message) =>
      _show(message, AppTheme.info, Icons.info_outline_rounded, 4500);

  static void _show(String message, Color tone, IconData icon, int ms) {
    final context = navigatorKey.currentContext;
    final overlay = context == null ? null : Navigator.of(context).overlay;
    if (overlay == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (overlay.mounted) {
        Toast.showOn(
          overlay,
          message,
          tone,
          icon,
          duration: Duration(milliseconds: ms),
        );
      }
    });
  }
}
