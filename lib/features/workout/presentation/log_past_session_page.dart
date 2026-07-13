import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../controllers/live_session_controller.dart';
import '../models/workout_session_model.dart';
import '../models/exercise_model.dart';
import 'widgets/add_exercise_sheet.dart';
import 'widgets/add_set_sheet.dart';

class LogPastSessionPage extends ConsumerStatefulWidget {
  const LogPastSessionPage({super.key});

  @override
  ConsumerState<LogPastSessionPage> createState() => _LogPastSessionPageState();
}

class _LogPastSessionPageState extends ConsumerState<LogPastSessionPage> {
  final _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final draft = ref.read(liveSessionControllerProvider).draft;
      if (draft != null) {
        _titleController.text = draft.title;
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, DateTime currentStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: currentStart,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      final newStart = DateTime(picked.year, picked.month, picked.day, currentStart.hour, currentStart.minute);
      ref.read(liveSessionControllerProvider.notifier).updatePastSessionTimes(startTime: newStart);
    }
  }

  Future<void> _selectTime(BuildContext context, DateTime current, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (picked != null) {
      final newTime = DateTime(current.year, current.month, current.day, picked.hour, picked.minute);
      if (isStart) {
        ref.read(liveSessionControllerProvider.notifier).updatePastSessionTimes(startTime: newTime);
      } else {
        ref.read(liveSessionControllerProvider.notifier).updatePastSessionTimes(endTime: newTime);
      }
    }
  }

  void _saveSession() async {
    final success = await ref.read(liveSessionControllerProvider.notifier).finishWorkout();
    if (success && context.mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(liveSessionControllerProvider);
    final draft = state.draft;

    if (draft == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final Map<String, List<WorkoutSetModel>> groupedSets = {};
    for (var set in draft.sets) {
      groupedSets.putIfAbsent(set.exerciseId, () => []).add(set);
    }
    
    // Auto calculate duration if start and end are provided
    final calculatedDuration = (draft.endTime != null) 
      ? draft.endTime!.difference(draft.startTime).inMinutes 
      : (draft.durationMinutes ?? 0);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.x, color: Colors.white),
          onPressed: () {
            ref.read(liveSessionControllerProvider.notifier).discardDraft();
            Navigator.pop(context);
          },
        ),
        title: const Text('Log Past Session', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('SESSION DETAILS', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const SizedBox(height: 12),
                
                TextField(
                  controller: _titleController,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Title',
                    labelStyle: const TextStyle(color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (val) => ref.read(liveSessionControllerProvider.notifier).updateTitle(val),
                ),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildPickerField(
                        label: 'Date',
                        value: DateFormat('dd MMM yyyy').format(draft.startTime),
                        icon: LucideIcons.calendar,
                        onTap: () => _selectDate(context, draft.startTime),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildPickerField(
                        label: 'Duration',
                        value: '$calculatedDuration min',
                        icon: LucideIcons.timer,
                        onTap: () {
                          // Could show a dialog to manually override duration, leaving as auto-calc for simplicity based on start/end
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildPickerField(
                        label: 'Start Time',
                        value: DateFormat('HH:mm').format(draft.startTime),
                        icon: LucideIcons.clock,
                        onTap: () => _selectTime(context, draft.startTime, true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildPickerField(
                        label: 'End Time',
                        value: draft.endTime != null ? DateFormat('HH:mm').format(draft.endTime!) : '--:--',
                        icon: LucideIcons.clock,
                        onTap: () => _selectTime(context, draft.endTime ?? draft.startTime.add(const Duration(hours: 1)), false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                const Text('EXERCISES', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const SizedBox(height: 16),
                
                ...groupedSets.entries.map((entry) {
                  final exerciseSets = entry.value;
                  final exerciseName = exerciseSets.first.exerciseName;
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            exerciseName.toUpperCase(),
                            style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => AddSetSheet(
                                  exercise: ExerciseModel(id: entry.key, name: exerciseName, targetMuscle: ''),
                                ),
                              );
                            },
                            icon: const Icon(LucideIcons.plus, size: 16),
                            label: const Text('Set'),
                            style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
                          ),
                        ],
                      ),
                      ...exerciseSets.map((set) => _buildSetRow(set)),
                      const SizedBox(height: 24),
                    ],
                  );
                }),
                
                // Add Exercise Button
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: OutlinedButton.icon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const AddExerciseSheet(),
                      );
                    },
                    icon: const Icon(LucideIcons.plusCircle),
                    label: const Text('ADD EXERCISE'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Save Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
            ),
            child: SafeArea(
              child: ElevatedButton(
                onPressed: state.isLoading ? null : _saveSession,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: state.isLoading 
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.save),
                        SizedBox(width: 8),
                        Text('SAVE SESSION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2)),
                      ],
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerField({required String label, required String value, required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(icon, size: 16, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetRow(WorkoutSetModel set) {
    return Dismissible(
      key: Key(set.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppTheme.error.withOpacity(0.2),
        child: const Icon(LucideIcons.trash2, color: AppTheme.error),
      ),
      onDismissed: (_) {
        ref.read(liveSessionControllerProvider.notifier).deleteSet(set.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              alignment: Alignment.center,
              child: Text(
                '${set.setNumber}',
                style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text('${set.weightKg} kg', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('${set.reps} reps', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: set.setType == 'dropset' ? Colors.orange.withOpacity(0.2) : (set.setType == 'warmup' ? Colors.blue.withOpacity(0.2) : Colors.transparent),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                set.setType == 'normal' ? '' : (set.setType == 'warmup' ? 'W' : 'D'),
                style: TextStyle(
                  color: set.setType == 'dropset' ? Colors.orange : Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            const Icon(LucideIcons.arrowLeft, size: 16, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}
