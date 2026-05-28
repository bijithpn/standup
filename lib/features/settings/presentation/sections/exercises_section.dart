import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/shared/widgets/minimal_controls.dart';
import 'package:breakmate/features/settings/exercise_model.dart';

class ExercisesSection extends StatefulWidget {
  final SettingsModel settings;
  final ValueChanged<SettingsModel> onSave;

  const ExercisesSection({
    super.key,
    required this.settings,
    required this.onSave,
  });

  @override
  State<ExercisesSection> createState() => _ExercisesSectionState();
}

class _ExercisesSectionState extends State<ExercisesSection> {
  @override
  Widget build(BuildContext context) {
    return _buildExercises();
  }

  Widget _buildExercises() {
    final exercises = widget.settings.exercises.isEmpty
        ? ExerciseModel.defaults
        : widget.settings.exercises;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader('Custom Exercises'),
        const Text(
          'Create unlimited custom break routines targeting your specific needs.',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 24),
        buildCard([
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                const Expanded(child: Text('Exercise Library')),
                MinimalButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  backgroundColor: AppTheme.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  onPressed: () => _showExerciseEditor(),
                  child: Text(
                    'Add Exercise',
                    style: TextStyle(color: AppTheme.accentColor, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          for (final exercise in exercises) ...[
            divider(),
            _exerciseSettingsItem(exercise),
          ],
        ]),
      ],
    );
  }

  void _showExerciseEditor({ExerciseModel? existing}) {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final durationController = TextEditingController(
      text: (existing?.durationSeconds ?? 20).toString(),
    );
    final instructionsController = TextEditingController(
      text: existing?.instructions ?? '',
    );
    var category = existing?.category ?? ExerciseCategory.stretch;

    showCupertinoDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return CupertinoAlertDialog(
            title: Text(existing == null ? 'Add Exercise' : 'Edit Exercise'),
            content: Column(
              children: [
                const SizedBox(height: 12),
                CupertinoTextField(
                  controller: titleController,
                  placeholder: 'Title',
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: durationController,
                  placeholder: 'Duration seconds',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: instructionsController,
                  placeholder: 'Instructions',
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                MinimalButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  isSecondary: true,
                  onPressed: () {
                    _showPicker(
                      title: 'Select Category',
                      options: ExerciseCategory.values
                          .map((c) => c.name)
                          .toList(),
                      suffix: '',
                      onSelected: (v) {
                        setDialogState(() {
                          category = ExerciseCategory.values.firstWhere(
                            (c) => c.name == v,
                          );
                        });
                      },
                    );
                  },
                  child: Text('Category: ${category.name}'),
                ),
              ],
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              CupertinoDialogAction(
                onPressed: () {
                  final title = titleController.text.trim();
                  final duration =
                      int.tryParse(durationController.text.trim()) ?? 20;
                  final instructions = instructionsController.text.trim();
                  if (title.isEmpty || instructions.isEmpty) return;
                  _upsertExercise(
                    ExerciseModel(
                      id:
                          existing?.id ??
                          'custom_${DateTime.now().millisecondsSinceEpoch}',
                      title: title,
                      durationSeconds: duration.clamp(5, 600),
                      category: category,
                      instructions: instructions,
                      enabled: existing?.enabled ?? true,
                    ),
                  );
                  Navigator.pop(context);
                },
                isDefaultAction: true,
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  IconData _exerciseIcon(ExerciseCategory category) {
    switch (category) {
      case ExerciseCategory.eyeRest:
        return CupertinoIcons.eye;
      case ExerciseCategory.posture:
        return CupertinoIcons.person_crop_circle;
      case ExerciseCategory.breathing:
        return CupertinoIcons.wind;
      case ExerciseCategory.movement:
        return CupertinoIcons.arrow_2_circlepath;
      case ExerciseCategory.stretch:
        return CupertinoIcons.person_2;
    }
  }

  void _upsertExercise(ExerciseModel exercise) {
    final exercises = List<ExerciseModel>.from(
      widget.settings.exercises.isEmpty
          ? ExerciseModel.defaults
          : widget.settings.exercises,
    );
    final index = exercises.indexWhere((e) => e.id == exercise.id);
    if (index == -1) {
      exercises.add(exercise);
    } else {
      exercises[index] = exercise;
    }
    widget.onSave(widget.settings.copyWith(exercises: exercises));
  }

  void _deleteExercise(ExerciseModel exercise) {
    final exercises = List<ExerciseModel>.from(
      widget.settings.exercises.isEmpty
          ? ExerciseModel.defaults
          : widget.settings.exercises,
    )..removeWhere((e) => e.id == exercise.id);
    widget.onSave(widget.settings.copyWith(exercises: exercises));
  }

  Widget _exerciseSettingsItem(ExerciseModel exercise) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            _exerciseIcon(exercise.category),
            color: AppTheme.accentColor,
            size: 20,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${exercise.durationSeconds}s ΓÇó ${exercise.category.name} ΓÇó ${exercise.instructions}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.8,
            alignment: Alignment.centerRight,
            child: CupertinoSwitch(
              value: exercise.enabled,
              activeTrackColor: AppTheme.accentColor,
              onChanged: (enabled) =>
                  _upsertExercise(exercise.copyWith(enabled: enabled)),
            ),
          ),
          MinimalButton(
            padding: EdgeInsets.zero,
            backgroundColor: Colors.transparent,
            onPressed: () => _showExerciseEditor(existing: exercise),
            child: const Icon(
              CupertinoIcons.pencil,
              size: 18,
              color: AppTheme.textSecondary,
            ),
          ),
          MinimalButton(
            padding: EdgeInsets.zero,
            backgroundColor: Colors.transparent,
            onPressed: () => _deleteExercise(exercise),
            child: const Icon(
              CupertinoIcons.delete,
              size: 18,
              color: CupertinoColors.systemRed,
            ),
          ),
        ],
      ),
    );
  }

  void _showPicker({
    required String title,
    required List<String> options,
    required String suffix,
    required ValueChanged<String> onSelected,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              width: 320,
              constraints: const BoxConstraints(maxHeight: 400),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Satoshi',
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: options.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        thickness: 0.5,
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                      itemBuilder: (context, index) {
                        final opt = options[index];
                        return InkWell(
                          onTap: () {
                            onSelected(opt);
                            Navigator.pop(context);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            child: Center(
                              child: Text(
                                '$opt$suffix',
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Satoshi',
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
    );
  }
}
