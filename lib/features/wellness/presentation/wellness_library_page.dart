import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:breakmate/features/settings/exercise_model.dart';
import 'package:breakmate/features/wellness/data/wellness_library_repository.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

class WellnessLibraryPage extends StatelessWidget {
  const WellnessLibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 600;
        final horizontalPadding = isSmall ? 16.0 : 40.0;
        final verticalPadding = isSmall ? 20.0 : 32.0;

        Widget buildContent(
          ScrollController? scrollController,
          List<ExerciseModel> exercises,
          WellnessLibraryRepository repo,
        ) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isSmall ? double.infinity : 800,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isSmall) ...[
                      const Text(
                        'Wellness Library',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Manage your break activities. Favorite what you love, hide what you don\'t.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isSmall ? 1 : 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: isSmall ? 1.8 : 1.45,
                      ),
                      itemCount: exercises.length,
                      itemBuilder: (context, index) {
                        final exercise = exercises[index];
                        return ExerciseCard(exercise: exercise, repo: repo);
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Consumer<WellnessLibraryRepository>(
          builder: (context, repo, child) {
            final exercises = repo.allExercises;

            if (isSmall) {
              return Scaffold(
                backgroundColor: AppTheme.surface,
                body: SafeArea(child: buildContent(null, exercises, repo)),
              );
            }

            return MacosScaffold(
              backgroundColor: AppTheme.surface,
              toolBar: const ToolBar(
                title: Text(
                  'Wellness Library',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                titleWidth: 260,
                actions: [],
              ),
              children: [
                ContentArea(
                  builder: (context, scrollController) =>
                      buildContent(scrollController, exercises, repo),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class ExerciseCard extends StatelessWidget {
  final ExerciseModel exercise;
  final WellnessLibraryRepository repo;

  const ExerciseCard({super.key, required this.exercise, required this.repo});

  @override
  Widget build(BuildContext context) {
    final isHidden = exercise.isHidden;

    return Container(
      decoration: BoxDecoration(
        color: isHidden
            ? AppTheme.surfaceCard.withValues(alpha: 0.4)
            : AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: exercise.isFavorite
              ? AppTheme.accent.withValues(alpha: 0.4)
              : AppTheme.border,
          width: exercise.isFavorite ? 1.5 : 1,
        ),
        boxShadow: isHidden
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    exercise.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isHidden
                          ? AppTheme.textMuted
                          : AppTheme.textPrimary,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                exercise.instructions,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: isHidden
                      ? AppTheme.textMuted.withValues(alpha: 0.6)
                      : AppTheme.textSecondary,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _getCategoryBadge(exercise.category),
                Row(
                  children: [
                    _ActionButton(
                      icon: exercise.isFavorite
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: exercise.isFavorite
                          ? Colors.amber
                          : AppTheme.textSecondary,
                      onPressed: () => repo.toggleFavorite(exercise.id),
                      semanticsLabel: 'Toggle favorite',
                    ),
                    const SizedBox(width: 8),
                    _ActionButton(
                      icon: isHidden
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: isHidden ? AppTheme.error : AppTheme.textSecondary,
                      onPressed: () => repo.toggleHidden(exercise.id),
                      semanticsLabel: 'Toggle visibility',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _getCategoryBadge(ExerciseCategory category) {
    IconData icon;
    Color color;
    String label;
    switch (category) {
      case ExerciseCategory.eyeRest:
        icon = LucideIcons.eye;
        color = AppTheme.info;
        label = 'Eye Rest';
        break;
      case ExerciseCategory.stretch:
        icon = LucideIcons.move;
        color = AppTheme.success;
        label = 'Stretch';
        break;
      case ExerciseCategory.posture:
        icon = LucideIcons.accessibility;
        color = AppTheme.warning;
        label = 'Posture';
        break;
      case ExerciseCategory.breathing:
        icon = LucideIcons.wind;
        color = Colors.teal;
        label = 'Breathing';
        break;
      case ExerciseCategory.movement:
        icon = LucideIcons.footprints;
        color = AppTheme.longBreak;
        label = 'Movement';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final String semanticsLabel;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onPressed,
    required this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      button: true,
      child: Tooltip(
        message: semanticsLabel,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
                width: 0.5,
              ),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }
}
