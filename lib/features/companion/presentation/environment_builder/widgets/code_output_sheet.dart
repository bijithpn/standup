import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/features/companion/presentation/environment_builder/environment_builder_controller.dart';

// Debug-only bottom sheet that displays the generated Dart code snippet and
// lets the user copy it with one tap. Gated by kDebugMode at call site.
class CodeOutputSheet extends StatelessWidget {
  final EnvironmentBuilderController controller;

  const CodeOutputSheet({super.key, required this.controller});

  static void show(
    BuildContext context,
    EnvironmentBuilderController controller,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CodeOutputSheet(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final code = controller.generateDartCode();
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Color(0xFF111113),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
              top: BorderSide(color: AppTheme.border, width: 0.5),
              left: BorderSide(color: AppTheme.border, width: 0.5),
              right: BorderSide(color: AppTheme.border, width: 0.5),
            ),
          ),
          child: Column(
            children: [
              _HandleBar(),
              _SheetHeader(onCopy: () => _copyCode(context, code)),
              _DebugBadge(),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  child: _CodeBlock(code: code),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _copyCode(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Dart code copied to clipboard',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500),
        ),
        backgroundColor: AppTheme.surfaceElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: AppTheme.border),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _HandleBar extends StatelessWidget {
  const _HandleBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppTheme.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final VoidCallback onCopy;

  const _SheetHeader({required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
      child: Row(
        children: [
          Icon(Icons.code_rounded, size: 18, color: AppTheme.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Generated Config Code',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: -0.2,
                fontFamily: 'Inter',
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded, size: 14),
            label: const Text(
              'Copy',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.accent.withValues(alpha: 0.15),
              foregroundColor: AppTheme.accent,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DebugBadge extends StatelessWidget {
  const _DebugBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: const [
          Icon(Icons.bug_report_rounded, size: 14, color: AppTheme.warning),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Debug mode only — paste this snippet into EnvironmentThemeConfig.themes to make it a built-in theme.',
              style: TextStyle(
                fontSize: 11.5,
                color: AppTheme.warning,
                fontFamily: 'Inter',
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  final String code;

  const _CodeBlock({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: SelectableText(
        code,
        style: const TextStyle(
          fontSize: 11.5,
          fontFamily: 'monospace',
          color: Color(0xFFE2E8F0),
          height: 1.6,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
