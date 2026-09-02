import 'package:flutter/material.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/animated_nature_backdrop.dart';

/// Full-screen animated poster for a quick reminder (posture / eye rest /
/// meeting-ready) shown when it's safe to take over the whole screen — see
/// `QuickReminderOverlay`'s `allowFullPoster` gate for when this is skipped
/// in favor of the small pill instead.
class PosterReminderOverlay extends StatelessWidget {
  final IconData icon;
  final String text;
  final Animation<double> fadeAnimation;
  final Color baseColorTop;
  final Color baseColorBottom;
  final List<Color> blobColors;

  const PosterReminderOverlay({
    super.key,
    required this.icon,
    required this.text,
    required this.fadeAnimation,
    required this.baseColorTop,
    required this.baseColorBottom,
    required this.blobColors,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedNatureBackdrop(
          baseColorTop: baseColorTop,
          baseColorBottom: baseColorBottom,
          blobColors: blobColors,
        ),
        Center(
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
                    child: Icon(icon, size: 40, color: Colors.black87),
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
        ),
      ],
    );
  }
}
