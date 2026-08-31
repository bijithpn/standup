import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/companion/services/custom_environment_repository.dart';
import 'package:breakmate/shared/shared.dart';
import 'environment_builder_controller.dart';
import 'widgets/env_preview_panel.dart';
import 'widgets/code_output_sheet.dart';
import 'widgets/picker_panel.dart';
import 'widgets/action_bar.dart';

class EnvironmentBuilderPage extends StatelessWidget {
  const EnvironmentBuilderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EnvironmentBuilderController(
        repository: sl<CustomEnvironmentRepository>(),
      ),
      child: const _EnvironmentBuilderBody(),
    );
  }
}

class _EnvironmentBuilderBody extends StatelessWidget {
  const _EnvironmentBuilderBody();

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const DesktopDragScrollBehavior(),
      child: Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: _buildAppBar(context),
        body: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 800) {
              return const _WideLayout();
            }
            return const _NarrowLayout();
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final controller = context.read<EnvironmentBuilderController>();
    return PreferredSize(
      preferredSize: const Size.fromHeight(76),
      child: Container(
        margin: const EdgeInsets.only(top: 20),
        child: AppBar(
          backgroundColor: AppTheme.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(CupertinoIcons.chevron_left, size: 18),
            color: AppTheme.textSecondary,
            onPressed: () => Navigator.pop(context),
            tooltip: 'Back',
          ),
          titleSpacing: 0,
          title: Text(
            'Environment Builder',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              letterSpacing: -0.2,
              fontFamily: 'Inter',
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(0.5),
            child: Container(height: 0.5, color: AppTheme.border),
          ),
          actions: [
            if (kDebugMode)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: TextButton.icon(
                  icon: const Icon(Icons.code_rounded, size: 14),
                  label: const Text('Get Code'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.warning,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                    ),
                  ),
                  onPressed: () => CodeOutputSheet.show(context, controller),
                ),
              ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _WideLayout extends StatefulWidget {
  const _WideLayout();

  @override
  State<_WideLayout> createState() => _WideLayoutState();
}

class _WideLayoutState extends State<_WideLayout> {
  double _pickerWidthRatio = 0.55;
  bool _isHoveringDivider = false;
  bool _isDraggingDivider = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final leftWidth = totalWidth * _pickerWidthRatio;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: leftWidth, child: const PickerPanel()),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (_) {
                setState(() => _isDraggingDivider = true);
              },
              onHorizontalDragEnd: (_) {
                setState(() => _isDraggingDivider = false);
              },
              onHorizontalDragCancel: () {
                setState(() => _isDraggingDivider = false);
              },
              onHorizontalDragUpdate: (details) {
                setState(() {
                  final deltaRatio = details.delta.dx / totalWidth;
                  _pickerWidthRatio = (_pickerWidthRatio + deltaRatio).clamp(
                    0.35,
                    0.75,
                  );
                });
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                onEnter: (_) => setState(() => _isHoveringDivider = true),
                onExit: (_) => setState(() => _isHoveringDivider = false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: 10,
                  color: (_isHoveringDivider || _isDraggingDivider)
                      ? AppTheme.accent.withValues(alpha: 0.1)
                      : Colors.transparent,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 1,
                        color: (_isHoveringDivider || _isDraggingDivider)
                            ? AppTheme.accent
                            : AppTheme.border,
                      ),
                      if (_isHoveringDivider || _isDraggingDivider)
                        Container(
                          width: 4,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppTheme.accent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const Expanded(child: _PreviewPanel()),
          ],
        );
      },
    );
  }
}

class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Consumer<EnvironmentBuilderController>(
              builder: (_, ctrl, _) => EnvPreviewPanel(theme: ctrl.draft),
            ),
          ),
        ),
        Divider(height: 0.5, thickness: 0.5, color: AppTheme.border),
        const Expanded(child: PickerPanel()),
      ],
    );
  }
}



class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<EnvironmentBuilderController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: EnvPreviewPanel(theme: ctrl.draft),
          ),
        ),
        Divider(height: 0.5, thickness: 0.5, color: AppTheme.border),
        ActionBar(ctrl: ctrl),
      ],
    );
  }
}
