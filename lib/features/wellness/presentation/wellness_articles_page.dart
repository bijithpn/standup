import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:standup/shared/theme/app_theme.dart';

class WellnessArticlesPage extends StatelessWidget {
  const WellnessArticlesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 750;
        
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            if (!isNarrow)
              CupertinoSliverNavigationBar(
                largeTitle: Text(
                  'Articles',
                  style: AppTheme.headerStyle.copyWith(fontSize: 32),
                ),
                backgroundColor: Colors.transparent,
                border: null,
              ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                isNarrow ? 16 : 32,
                isNarrow ? 16 : 0,
                isNarrow ? 16 : 32,
                isNarrow ? 32 : 48,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildArticleCard(
                    title: 'The 20-20-20 Rule',
                    subtitle: 'Reduce eye strain by looking 20 feet away every 20 minutes for 20 seconds.',
                    icon: CupertinoIcons.eye_fill,
                    color: const Color(0xFF007AFF),
                    isNarrow: isNarrow,
                  ),
                  const SizedBox(height: 16),
                  _buildArticleCard(
                    title: 'Perfect Sitting Posture',
                    subtitle: 'Keep your back straight, shoulders back, and feet flat on the floor.',
                    icon: CupertinoIcons.person_fill,
                    color: const Color(0xFF32D74B),
                    isNarrow: isNarrow,
                  ),
                  const SizedBox(height: 16),
                  _buildArticleCard(
                    title: 'Hydration & Productivity',
                    subtitle: 'Drinking water regularly helps maintain focus and energy levels throughout the day.',
                    icon: CupertinoIcons.drop_fill,
                    color: const Color(0xFF64D2FF),
                    isNarrow: isNarrow,
                  ),
                  const SizedBox(height: 16),
                  _buildArticleCard(
                    title: 'Micro-breaks Matter',
                    subtitle: 'Short, frequent breaks are more effective than long, infrequent ones for cognitive health.',
                    icon: CupertinoIcons.timer_fill,
                    color: const Color(0xFFFF9F0A),
                    isNarrow: isNarrow,
                  ),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildArticleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool isNarrow = false,
  }) {
    return AppTheme.glassContainer(
      child: Padding(
        padding: EdgeInsets.all(isNarrow ? 20.0 : 24.0),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isNarrow ? 12 : 14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: isNarrow ? 22 : 26),
            ),
            SizedBox(width: isNarrow ? 16 : 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.subHeaderStyle.copyWith(
                      fontSize: isNarrow ? 16 : 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: AppTheme.tipStyle.copyWith(
                      fontSize: isNarrow ? 12 : 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(CupertinoIcons.chevron_right, color: AppTheme.textMuted, size: 14),
          ],
        ),
      ),
    );
  }
}
