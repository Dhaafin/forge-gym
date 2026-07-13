import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../controllers/exercise_controller.dart';
import '../../models/exercise_model.dart';
import 'add_set_sheet.dart';

class AddExerciseSheet extends ConsumerStatefulWidget {
  const AddExerciseSheet({super.key});

  @override
  ConsumerState<AddExerciseSheet> createState() => _AddExerciseSheetState();
}

class _AddExerciseSheetState extends ConsumerState<AddExerciseSheet> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onExerciseSelected(ExerciseModel exercise) {
    Navigator.pop(context); // close exercise sheet
    // immediately show add set sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddSetSheet(exercise: exercise),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(exerciseControllerProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('Add Exercise', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search exercise...',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (val) {
                    ref.read(exerciseControllerProvider.notifier).setSearch(val.trim());
                  },
                ),
              ),
              Expanded(
                child: state.isLoadingFirst
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                    : ListView.builder(
                        controller: controller,
                        itemCount: state.exercises.length,
                        itemBuilder: (context, index) {
                          final exercise = state.exercises[index];
                          return ListTile(
                            title: Text(exercise.name, style: const TextStyle(color: Colors.white)),
                            subtitle: Text(exercise.targetMuscle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                            trailing: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primary),
                            onTap: () => _onExerciseSelected(exercise),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
