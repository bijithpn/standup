import 'package:flutter/material.dart';

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

    return RepaintBoundary(
      child: Text(
        display,
        style: const TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.w300,
          color: Colors.white,
          letterSpacing: -1,
        ),
      ),
    );
  }
}
