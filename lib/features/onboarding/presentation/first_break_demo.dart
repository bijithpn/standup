import 'package:clock/clock.dart';
import 'dart:async';
import 'package:flutter/material.dart';

/// An optional practice break. It never starts the timer or writes break history.
class FirstBreakDemo extends StatefulWidget {
  const FirstBreakDemo({super.key});
  @override
  State<FirstBreakDemo> createState() => _FirstBreakDemoState();
}

class _FirstBreakDemoState extends State<FirstBreakDemo> {
  Timer? _timer;
  late DateTime _end;
  int _remaining = 20;

  @override
  void initState() {
    super.initState();
    _end = clock.now().add(const Duration(seconds: 20));
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final remaining = (_end.difference(clock.now()).inMilliseconds / 1000)
          .ceil()
          .clamp(0, 20);
      if (remaining != _remaining) setState(() => _remaining = remaining);
      if (remaining == 0) _timer?.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      _remaining == 0
          ? 'Your first practice break is complete'
          : 'Rest your eyes',
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _remaining == 0 ? 'Ready when you are' : '$_remaining seconds',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 20),
        Text(
          _remaining == 0
              ? 'You can take a break, snooze, or pause from Today or the menu bar.'
              : 'Look away from your screen at something in the distance. Relax your shoulders and breathe comfortably.',
        ),
        const SizedBox(height: 12),
        const Text('This demo does not change your statistics.'),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(_remaining == 0 ? 'Done' : 'End demo'),
      ),
    ],
  );
}
