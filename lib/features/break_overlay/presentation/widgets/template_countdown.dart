import 'package:flutter/material.dart';

class TemplateCountdown extends StatelessWidget {
  final int remainingSeconds;

  const TemplateCountdown({super.key, required this.remainingSeconds});

  @override
  Widget build(BuildContext context) {
    return Text('$remainingSeconds');
  }
}
