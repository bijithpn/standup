import 'package:flutter/material.dart';
import 'package:standup/features/flash_overlay/flash_overlay_service.dart';
import 'package:standup/features/flash_overlay/flash_overlay_widget.dart';
import 'package:window_manager/window_manager.dart';

/// Screen that hosts the flash overlay
class FlashOverlayScreen extends StatelessWidget {
  final FlashOverlayService overlayService;

  const FlashOverlayScreen({
    super.key,
    required this.overlayService,
  });

  @override
  Widget build(BuildContext context) {
    return FlashOverlayWidget(
      overlayService: overlayService,
      onClose: () async {
        await windowManager.hide();
      },
    );
  }
}
