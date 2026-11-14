import 'package:flutter/material.dart';

/// Large centered icon + text reminder shown when a full poster is allowed.
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
