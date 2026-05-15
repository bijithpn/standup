/// Flash Overlay System
/// 
/// Full-screen flash overlay for accessibility visual alerts.
/// Behaves like macOS/iOS "Flash the screen" feature.
/// 
/// Quick start:
/// ```dart
/// // Simple usage
/// FlashService.flash();
/// 
/// // Custom color
/// FlashService.flash(color: Colors.red);
/// 
/// // Multiple pulses
/// FlashService.flashPulse(color: Colors.blue, flashCount: 3);
/// 
/// // From context
/// context.flashScreen(color: Colors.green);
/// ```
library;

export 'flash_controller.dart';
export 'flash_overlay.dart';
export 'flash_service.dart';
export 'flash_test_widget.dart';
