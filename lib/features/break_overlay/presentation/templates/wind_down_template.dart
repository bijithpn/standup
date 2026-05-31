import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

class WindDownTemplate extends StatelessWidget {
  const WindDownTemplate({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<StatsService>().stats;
    final breakController = context.watch<BreakController>();

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.sunset, size: 64, color: Colors.orangeAccent),
            const SizedBox(height: 24),
            const Text(
              'Workday Wrap-up',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Time to disconnect and recharge. Here is your daily summary:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatItem(
                  icon: LucideIcons.timer,
                  value: '${(stats.dailyUsageMinutes / 60).toStringAsFixed(1)}h',
                  label: 'Focus Time',
                ),
                _StatItem(
                  icon: LucideIcons.coffee,
                  value: '${stats.breaksCompleted}',
                  label: 'Breaks Taken',
                ),
                _StatItem(
                  icon: LucideIcons.trendingUp,
                  value: '${stats.productivityScore}%',
                  label: 'Efficiency',
                ),
              ],
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => breakController.completeCurrentBreak(),
              icon: const Icon(LucideIcons.logOut),
              label: const Text('Finish My Day'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.grey),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
