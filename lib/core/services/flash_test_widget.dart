import 'package:flutter/material.dart';
import 'package:standup/core/services/flash_service.dart';

/// Example widget demonstrating flash overlay usage
/// 
/// This widget provides buttons to test different flash configurations.
/// You can use this as a reference or remove it in production.
class FlashTestWidget extends StatelessWidget {
  const FlashTestWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Flash Overlay Test',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Test different flash configurations:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Default flash
                ElevatedButton(
                  onPressed: () => FlashService.instance.flash(),
                  child: const Text('Default Flash'),
                ),
                
                // Red flash
                ElevatedButton(
                  onPressed: () => FlashService.instance.flash(
                    color: Colors.red,
                    opacity: 0.7,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Red Flash'),
                ),
                
                // Blue flash
                ElevatedButton(
                  onPressed: () => FlashService.instance.flash(
                    color: Colors.blueAccent,
                    opacity: 0.6,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Blue Flash'),
                ),
                
                // Green flash
                ElevatedButton(
                  onPressed: () => FlashService.instance.flash(
                    color: Colors.green,
                    opacity: 0.5,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Green Flash'),
                ),
                
                // Pulse flash (3 rapid flashes)
                ElevatedButton(
                  onPressed: () => FlashService.instance.flashPulse(
                    color: Colors.orange,
                    flashCount: 3,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Pulse (3x)'),
                ),
                
                // Accessibility flash
                ElevatedButton(
                  onPressed: () => FlashService.instance.flashAccessibility(
                    color: Colors.white,
                  ),
                  child: const Text('Accessibility'),
                ),
                
                // Custom configuration
                ElevatedButton(
                  onPressed: () => FlashService.instance.flash(
                    color: Colors.purple,
                    opacity: 0.8,
                    flashCount: 2,
                    flashInDuration: const Duration(milliseconds: 50),
                    holdDuration: const Duration(milliseconds: 150),
                    fadeOutDuration: const Duration(milliseconds: 250),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Custom (2x)'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple button widget for triggering flash
class FlashButton extends StatelessWidget {
  final Color? color;
  final int flashCount;
  final String label;
  final VoidCallback? onPressed;

  const FlashButton({
    super.key,
    this.color,
    this.flashCount = 1,
    this.label = 'Flash Screen',
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        // Call custom callback if provided
        onPressed?.call();
        
        // Always trigger flash
        FlashService.instance.flash(
          color: color ?? Colors.white,
          opacity: 0.8,
          flashCount: flashCount,
        );
      },
      child: Text(label),
    );
  }
}
