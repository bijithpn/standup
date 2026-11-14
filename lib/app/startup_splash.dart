import 'package:breakmate/shared/utils/reduced_motion.dart';
import 'package:flutter/material.dart';

import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// Minimal splash shown via runApp() while services bootstrap, before DI is ready.
class StartupSplash extends StatelessWidget {
  const StartupSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppTheme.sidebarBackground,
        body: const StartupSplashContent(),
      ),
    );
  }
}

class StartupSplashContent extends StatefulWidget {
  const StartupSplashContent({super.key});

  @override
  State<StartupSplashContent> createState() => _StartupSplashContentState();
}

class _StartupSplashContentState extends State<StartupSplashContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeatUnlessReducedMotion(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, _) {
          final t = Curves.easeInOut.transform(_ctrl.value);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: 0.7 + 0.3 * t,
                child: Transform.scale(
                  scale: 0.94 + 0.06 * t,
                  child: Image.asset(
                    AppConstants.trayIconPath,
                    width: 72,
                    height: 72,
                    errorBuilder: (_, _, _) =>
                        const SizedBox(width: 72, height: 72),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 120,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: const LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: Color(0x22FFFFFF),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Overlay on top of the real app that fades the splash out after first build.
class StartupSplashCover extends StatefulWidget {
  const StartupSplashCover({super.key});

  @override
  State<StartupSplashCover> createState() => _StartupSplashCoverState();
}

class _StartupSplashCoverState extends State<StartupSplashCover>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
    value: 1,
  );
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (prefersReducedMotion) {
        if (mounted) setState(() => _gone = true);
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      await _fade.reverse();
      if (mounted) setState(() => _gone = true);
    });
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_gone) return const SizedBox.shrink();
    return IgnorePointer(
      child: FadeTransition(
        opacity: _fade,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: ColoredBox(
            color: AppTheme.sidebarBackground,
            child: const StartupSplashContent(),
          ),
        ),
      ),
    );
  }
}
