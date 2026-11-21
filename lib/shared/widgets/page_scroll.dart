import 'package:flutter/material.dart';

import 'package:breakmate/shared/theme/app_theme.dart';

/// Scroll container shared by every shell page: scrollbar at the window edge, centered content column with a fixed side gutter.
class PageScroll extends StatefulWidget {
  const PageScroll({super.key, required this.child});

  static const double maxContentWidth = 1120;

  final Widget child;

  @override
  State<PageScroll> createState() => _PageScrollState();
}

class _PageScrollState extends State<PageScroll> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      child: SingleChildScrollView(
        // AppTheme colours are static reads; keying on the theme rebuilds the cached page on preset change.
        key: ValueKey(Theme.of(context)),
        controller: _controller,
        padding: const EdgeInsets.fromLTRB(
          AppTheme.space40,
          AppTheme.space32,
          AppTheme.space40,
          AppTheme.space40,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: PageScroll.maxContentWidth,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
