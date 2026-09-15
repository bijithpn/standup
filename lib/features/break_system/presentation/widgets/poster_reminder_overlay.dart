import 'package:flutter/material.dart';

/// Full-screen "poster" for a quick reminder (posture / eye rest /
/// meeting-ready) shown when it's safe to take over the whole screen — see
/// `QuickReminderOverlay`'s `allowFullPoster` gate for when this is skipped
/// in favor of the small pill instead. Deliberately plain: an icon naming
/// what the reminder is actually about (not the app's own logo — that told
/// the user nothing about posture vs. eye rest) and a one-line message,
/// over whatever's already on screen — the parent overlay
/// (`StandaloneBreakOverlay`) paints a low-opacity dark scrim behind this
/// so the user still sees their own desktop, not an opaque colored
/// background. Simple and brief by design: on screen only for the
/// reminder's short auto-dismiss window.
class PosterReminderOverlay extends StatelessWidget {
  final IconData icon;
  final String text;
  final Animation<double> fadeAnimation;

  const PosterReminderOverlay({
    super.key,
    required this.icon,
    required this.text,
    required this.fadeAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: fadeAnimation,
          curve: Curves.easeOut,
          reverseCurve: Curves.easeIn,
        ),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(
            CurvedAnimation(
              parent: fadeAnimation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeIn,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(icon, size: 48, color: Colors.black87),
              ),
              const SizedBox(height: 28),
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
