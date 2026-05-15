import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:standup/shared/theme/app_theme.dart';

class WellnessArticlesPage extends StatelessWidget {
  const WellnessArticlesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const CupertinoSliverNavigationBar(
          largeTitle: Text('Wellness Articles'),
          backgroundColor: Colors.transparent,
          border: null,
        ),
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildArticleCard(
                title: 'The 20-20-20 Rule',
                subtitle: 'Reduce eye strain by looking 20 feet away every 20 minutes for 20 seconds.',
                icon: CupertinoIcons.eye_fill,
                color: Colors.blue,
              ),
              const SizedBox(height: 16),
              _buildArticleCard(
                title: 'Perfect Sitting Posture',
                subtitle: 'Keep your back straight, shoulders back, and feet flat on the floor.',
                icon: CupertinoIcons.person_fill,
                color: Colors.green,
              ),
              const SizedBox(height: 16),
              _buildArticleCard(
                title: 'Hydration & Productivity',
                subtitle: 'Drinking water regularly helps maintain focus and energy levels throughout the day.',
                icon: CupertinoIcons.drop_fill,
                color: Colors.cyan,
              ),
              const SizedBox(height: 16),
              _buildArticleCard(
                title: 'Micro-breaks Matter',
                subtitle: 'Short, frequent breaks are more effective than long, infrequent ones for cognitive health.',
                icon: CupertinoIcons.timer_fill,
                color: Colors.orange,
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildArticleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return AppTheme.glassContainer(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTheme.subHeaderStyle.copyWith(fontSize: 16, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: AppTheme.tipStyle.copyWith(fontSize: 13)),
                ],
              ),
            ),
            const Icon(CupertinoIcons.chevron_right, color: AppTheme.textMuted, size: 14),
          ],
        ),
      ),
    );
  }
}
