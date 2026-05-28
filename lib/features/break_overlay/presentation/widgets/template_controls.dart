import 'package:flutter/material.dart';

class TemplateControls extends StatelessWidget {
  final VoidCallback onSkip;
  final VoidCallback onPostpone;
  
  const TemplateControls({super.key, required this.onSkip, required this.onPostpone});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TextButton(onPressed: onSkip, child: const Text('Skip')),
        TextButton(onPressed: onPostpone, child: const Text('Postpone')),
      ],
    );
  }
}
