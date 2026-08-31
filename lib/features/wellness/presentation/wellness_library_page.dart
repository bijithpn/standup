import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:breakmate/features/settings/exercise_model.dart';
import 'package:breakmate/features/wellness/data/wellness_library_repository.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

class _CategoryStyle {
  final IconData icon;
  final Color color;
  final String label;

  const _CategoryStyle(this.icon, this.color, this.label);
}

final Map<ExerciseCategory, _CategoryStyle> _categoryStyles = {
  ExerciseCategory.eyeRest: _CategoryStyle(
    LucideIcons.eye,
    AppTheme.info,
    'Eye Rest',
  ),
  ExerciseCategory.stretch: _CategoryStyle(
    LucideIcons.move,
    AppTheme.success,
    'Stretch',
  ),
  ExerciseCategory.posture: _CategoryStyle(
    LucideIcons.accessibility,
    AppTheme.warning,
    'Posture',
  ),
  ExerciseCategory.breathing: _CategoryStyle(
    LucideIcons.wind,
    Colors.teal,
    'Breathing',
  ),
  ExerciseCategory.movement: _CategoryStyle(
    LucideIcons.footprints,
    AppTheme.longBreak,
    'Movement',
  ),
};

class WellnessLibraryPage extends StatefulWidget {
  const WellnessLibraryPage({super.key});

  @override
  State<WellnessLibraryPage> createState() => _WellnessLibraryPageState();
}

class _WellnessLibraryPageState extends State<WellnessLibraryPage> {
  // null = All, otherwise a category filter. A separate flag drives the
  // "Favorites" chip since it cuts across categories.
  ExerciseCategory? _categoryFilter;
  bool _favoritesOnly = false;

  List<ExerciseModel> _filtered(List<ExerciseModel> all) {
    return all.where((e) {
      if (_favoritesOnly && !e.isFavorite) return false;
      if (_categoryFilter != null && e.category != _categoryFilter) {
        return false;
      }
      return true;
    }).toList();
  }

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
          final filtered = _filtered(exercises);
          final favoriteCount = exercises.where((e) => e.isFavorite).length;
          final activeCount = exercises.where((e) => !e.isHidden).length;

          return SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isSmall ? double.infinity : 860,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isSmall) ...[
                      Text(
                        'Wellness Library',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Manage your break activities. Favorite what you love, hide what you don\'t.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    _StatsRow(
                      total: exercises.length,
                      active: activeCount,
                      favorites: favoriteCount,
                    ),
                    const SizedBox(height: 20),
                    _FilterBar(
                      selectedCategory: _categoryFilter,
                      favoritesOnly: _favoritesOnly,
                      onSelectCategory: (cat) =>
                          setState(() => _categoryFilter = cat),
                      onToggleFavorites: () => setState(
                        () => _favoritesOnly = !_favoritesOnly,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (filtered.isEmpty)
                      _EmptyState(
                        favoritesOnly: _favoritesOnly,
                        category: _categoryFilter,
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: isSmall ? 1 : 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: isSmall ? 1.7 : 1.5,
                            ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final exercise = filtered[index];
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
              toolBar: ToolBar(
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

class _StatsRow extends StatelessWidget {
  final int total;
  final int active;
  final int favorites;

  const _StatsRow({
    required this.total,
    required this.active,
    required this.favorites,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: LucideIcons.libraryBig,
                color: AppTheme.info,
                value: '$total',
                label: 'Activities',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                icon: Icons.star_rounded,
                color: Colors.amber,
                value: '$favorites',
                label: 'Favorites',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                icon: LucideIcons.eye,
                color: AppTheme.success,
                value: '$active',
                label: 'Active',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: AppTheme.cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.3,
                    fontFamily: 'Inter',
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                    fontFamily: 'Inter',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final ExerciseCategory? selectedCategory;
  final bool favoritesOnly;
  final ValueChanged<ExerciseCategory?> onSelectCategory;
  final VoidCallback onToggleFavorites;

  const _FilterBar({
    required this.selectedCategory,
    required this.favoritesOnly,
    required this.onSelectCategory,
    required this.onToggleFavorites,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: 'All',
            icon: LucideIcons.layoutGrid,
            color: AppTheme.accent,
            selected: selectedCategory == null,
            onTap: () => onSelectCategory(null),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Favorites',
            icon: Icons.star_rounded,
            color: Colors.amber,
            selected: favoritesOnly,
            onTap: onToggleFavorites,
          ),
          const SizedBox(width: 8),
          Container(
            width: 1,
            height: 20,
            color: AppTheme.border,
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),
          const SizedBox(width: 8),
          for (final entry in _categoryStyles.entries) ...[
            _FilterChip(
              label: entry.value.label,
              icon: entry.value.icon,
              color: entry.value.color,
              selected: selectedCategory == entry.key,
              onTap: () => onSelectCategory(entry.key),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.14) : AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.4) : AppTheme.border,
              width: selected ? 1.2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: selected ? color : AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? color : AppTheme.textSecondary,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool favoritesOnly;
  final ExerciseCategory? category;

  const _EmptyState({required this.favoritesOnly, required this.category});

  @override
  Widget build(BuildContext context) {
    final message = favoritesOnly
        ? 'Star an activity to add it to your favorites.'
        : 'No activities match this filter yet.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        children: [
          Icon(
            favoritesOnly ? Icons.star_outline_rounded : LucideIcons.searchX,
            size: 32,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class ExerciseCard extends StatefulWidget {
  final ExerciseModel exercise;
  final WellnessLibraryRepository repo;

  const ExerciseCard({super.key, required this.exercise, required this.repo});

  @override
  State<ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<ExerciseCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final repo = widget.repo;
    final isHidden = exercise.isHidden;
    final style = _categoryStyles[exercise.category]!;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isHidden
              ? AppTheme.surfaceCard.withValues(alpha: 0.4)
              : AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: exercise.isFavorite
                ? AppTheme.accent.withValues(alpha: 0.4)
                : (_isHovering ? AppTheme.border.withValues(alpha: 0.8) : AppTheme.border),
            width: exercise.isFavorite ? 1.5 : 1,
          ),
          boxShadow: isHidden
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: _isHovering ? 0.16 : 0.1),
                    blurRadius: _isHovering ? 16 : 10,
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isHidden ? AppTheme.textMuted : style.color)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Icon(
                      style.icon,
                      size: 16,
                      color: isHidden ? AppTheme.textMuted : style.color,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
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
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.clock,
                              size: 11,
                              color: AppTheme.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${exercise.durationSeconds}s · ${style.label}',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textMuted,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
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
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isHidden) ...[
                    Text(
                      'Hidden',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMuted,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const Spacer(),
                  ],
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
        ),
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
