import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/flash_message.dart';
import '../../controllers/exercise_controller.dart';
import '../../models/exercise_model.dart';

Future<ExerciseModel?> showExerciseFormSheet(
  BuildContext context, {
  ExerciseModel? exercise,
}) {
  return showModalBottomSheet<ExerciseModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return Consumer(
        builder: (context, ref, _) {
          return ExerciseFormSheet(
            exercise: exercise,
            ref: ref,
            parentContext: context,
          );
        },
      );
    },
  );
}

class ExerciseFormSheet extends StatefulWidget {
  final ExerciseModel? exercise;
  final WidgetRef ref;
  final BuildContext parentContext;

  const ExerciseFormSheet({
    super.key,
    this.exercise,
    required this.ref,
    required this.parentContext,
  });

  @override
  State<ExerciseFormSheet> createState() => _ExerciseFormSheetState();
}

class _ExerciseFormSheetState extends State<ExerciseFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String _selectedMuscle;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.exercise?.name);
    _selectedMuscle = widget.exercise?.targetMuscle ?? 'Chest';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.exercise == null ? 'Create New Exercise' : 'Edit Exercise',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppTheme.primary,
                        fontSize: 20,
                      ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Exercise Name',
                    hintText: 'e.g. Bench Press',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _TargetMuscleSelector(
                  value: _selectedMuscle,
                  onChanged: (val) {
                    setState(() {
                      _selectedMuscle = val;
                    });
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            setState(() {
                              _isLoading = true;
                            });
                            try {
                              if (widget.exercise == null) {
                                final created = await widget.ref
                                    .read(exerciseControllerProvider.notifier)
                                    .createExercise(
                                      _nameController.text.trim(),
                                      _selectedMuscle,
                                    );
                                if (widget.parentContext.mounted) {
                                  widget.parentContext.showSuccessFlash('Exercise created successfully');
                                }
                                if (context.mounted) Navigator.pop(context, created);
                              } else {
                                await widget.ref
                                    .read(exerciseControllerProvider.notifier)
                                    .updateExercise(
                                      widget.exercise!.id,
                                      _nameController.text.trim(),
                                      _selectedMuscle,
                                    );
                                if (widget.parentContext.mounted) {
                                  widget.parentContext.showSuccessFlash('Exercise updated successfully');
                                }
                                if (context.mounted) Navigator.pop(context);
                              }
                            } catch (e) {
                              setState(() {
                                _isLoading = false;
                              });
                              if (widget.parentContext.mounted) {
                                widget.parentContext.showErrorFlash(e.toString().replaceAll('Exception: ', ''));
                              }
                            }
                          }
                        },
                  child: Text(widget.exercise == null ? 'CREATE' : 'SAVE CHANGES'),
                ),
              ],
            ),
          ),
        ),
        if (_isLoading)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(
                  color: Colors.black.withOpacity(0.65),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: AppTheme.primary),
                        const SizedBox(height: 16),
                        Text(
                          widget.exercise == null ? 'Creating exercise...' : 'Saving changes...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TargetMuscleSelector extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _TargetMuscleSelector({
    required this.value,
    required this.onChanged,
  });

  @override
  State<_TargetMuscleSelector> createState() => _TargetMuscleSelectorState();
}

class _TargetMuscleSelectorState extends State<_TargetMuscleSelector> {
  bool _isExpanded = false;
  final List<String> _muscles = ['Chest', 'Back', 'Legs', 'Arms', 'Shoulders'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isExpanded ? AppTheme.primary : Colors.white.withOpacity(0.1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Target Muscle',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.value,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Icon(
                  _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: _isExpanded ? AppTheme.primary : AppTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _isExpanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _muscles.map((muscle) {
                        final isSelected = widget.value == muscle;
                        return ChoiceChip(
                          label: Text(muscle),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              widget.onChanged(muscle);
                              setState(() {
                                _isExpanded = false;
                              });
                            }
                          },
                          selectedColor: AppTheme.primary,
                          backgroundColor: Colors.transparent,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.black : AppTheme.textPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected ? AppTheme.primary : Colors.white.withOpacity(0.1),
                            ),
                          ),
                          showCheckmark: false,
                        );
                      }).toList(),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
