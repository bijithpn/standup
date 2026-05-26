import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

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
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                isNarrow ? 16 : 32,
                isNarrow ? 16 : 32,
                isNarrow ? 16 : 32,
                16,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Wellness Articles',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tips and guides for healthy work habits',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                isNarrow ? 16 : 32,
                0,
                isNarrow ? 16 : 32,
                isNarrow ? 32 : 48,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildArticleCard(
                    title: 'The 20-20-20 Rule',
                    subtitle: 'Reduce eye strain by looking 20 feet away every 20 minutes for 20 seconds.',
                    icon: LucideIcons.eye,
                    color: AppTheme.shortBreak,
                    isNarrow: isNarrow,
                  ),
                  const SizedBox(height: 12),
                  _buildArticleCard(
                    title: 'Perfect Sitting Posture',
                    subtitle: 'Keep your back straight, shoulders back, and feet flat on the floor.',
                    icon: LucideIcons.user,
                    color: AppTheme.success,
                    isNarrow: isNarrow,
                  ),
                  const SizedBox(height: 12),
                  _buildArticleCard(
                    title: 'Hydration & Productivity',
                    subtitle: 'Drinking water regularly helps maintain focus and energy levels.',
                    icon: LucideIcons.droplet,
                    color: AppTheme.info,
                    isNarrow: isNarrow,
                  ),
                  const SizedBox(height: 12),
                  _buildArticleCard(
                    title: 'Micro-breaks Matter',
                    subtitle: 'Short, frequent breaks are more effective than long, infrequent ones.',
                    icon: LucideIcons.clock,
                    color: AppTheme.warning,
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
    return Container(
      padding: EdgeInsets.all(isNarrow ? 16.0 : 20.0),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isNarrow ? 10 : 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: color, size: isNarrow ? 20 : 24),
          ),
          SizedBox(width: isNarrow ? 14 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isNarrow ? 15 : 16,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: isNarrow ? 12 : 13,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(LucideIcons.chevronRight, color: AppTheme.textMuted, size: 16),
        ],
      ),
    );
  }
}
