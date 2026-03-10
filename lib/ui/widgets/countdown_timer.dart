import 'package:flutter/material.dart';
import 'package:standup/ui/theme/app_theme.dart';

class CountdownTimerWidget extends StatelessWidget {
  final int remainingSeconds;
  final int totalSeconds;

  const CountdownTimerWidget({
    super.key,
    required this.remainingSeconds,
    required this.totalSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    final display = totalSeconds >= 60
        ? '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
        : '$seconds';

    return Text(display, style: AppTheme.countdownStyle);
  }
}
