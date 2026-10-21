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
        Text(
          'Create unlimited custom break routines targeting your specific needs.',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 24),
        buildCard([
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Exercise Library',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                MinimalButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  backgroundColor: AppTheme.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  onPressed: () => _showExerciseEditor(),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.plus,
                        size: 14,
                        color: AppTheme.accentColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Add Exercise',
                        style: TextStyle(
                          color: AppTheme.accentColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
    ).whenComplete(() {
      // The route's future completes as the dismiss animation starts, so wait
      // for it to finish before the fields stop being listened to.
      Future.delayed(const Duration(milliseconds: 400), () {
        titleController.dispose();
        durationController.dispose();
        instructionsController.dispose();
      });
    });
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _exerciseIcon(exercise.category),
                  color: AppTheme.accentColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  exercise.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              CupertinoSwitch(
                value: exercise.enabled,
                activeTrackColor: AppTheme.accentColor,
                onChanged: (enabled) =>
                    _upsertExercise(exercise.copyWith(enabled: enabled)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '${exercise.durationSeconds}s',
                style: TextStyle(
                  color: AppTheme.accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text('•', style: TextStyle(color: AppTheme.textMuted)),
              const SizedBox(width: 8),
              Text(
                exercise.category.name.toUpperCase(),
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            exercise.instructions,
            style: TextStyle(
              color: AppTheme.textSecondary.withValues(alpha: 0.8),
              fontSize: 13,
              height: 1.4,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              MinimalButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                backgroundColor: AppTheme.surfaceElevated,
                onPressed: () => _showExerciseEditor(existing: exercise),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.pencil,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Edit',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              MinimalButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                backgroundColor: Colors.transparent,
                onPressed: () => _deleteExercise(exercise),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.delete,
                      size: 14,
                      color: CupertinoColors.systemRed.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Delete',
                      style: TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.systemRed,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                                style: TextStyle(
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
