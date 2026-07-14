import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/notification_manager.dart';
import '../../../core/utils/flash_message.dart';
import '../controllers/live_session_controller.dart';
import '../models/workout_session_model.dart';
import '../models/exercise_model.dart';
import 'widgets/add_exercise_sheet.dart';
import 'widgets/add_set_sheet.dart';

class LiveSessionPage extends ConsumerStatefulWidget {
  const LiveSessionPage({super.key});

  @override
  ConsumerState<LiveSessionPage> createState() => _LiveSessionPageState();
}

class _LiveSessionPageState extends ConsumerState<LiveSessionPage> {
  final _titleController = TextEditingController();
  bool _isEditingTitle = false;

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

  void _finishWorkout() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _FinishWorkoutSummarySheet(parentContext: context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(liveSessionControllerProvider);
    final draft = state.draft;

    if (draft == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final minutes = state.elapsedTime.inMinutes.toString().padLeft(2, '0');
    final seconds = (state.elapsedTime.inSeconds % 60).toString().padLeft(2, '0');

    // Group sets by exercise
    final Map<String, List<WorkoutSetModel>> groupedSets = {};
    for (var set in draft.sets) {
      groupedSets.putIfAbsent(set.exerciseId, () => []).add(set);
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        // App goes to background or user presses back.
        // We shouldn't stop the session if they just press back, or maybe we just minimize.
        // Session stays active in background.
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: _isEditingTitle
              ? TextField(
                  controller: _titleController,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  autofocus: true,
                  decoration: const InputDecoration(border: InputBorder.none, hintText: 'Workout Title', hintStyle: TextStyle(color: Colors.white54)),
                  onSubmitted: (val) {
                    setState(() => _isEditingTitle = false);
                    ref.read(liveSessionControllerProvider.notifier).updateTitle(val);
                  },
                )
              : GestureDetector(
                  onTap: () => setState(() => _isEditingTitle = true),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(draft.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      const Icon(Icons.edit_rounded, size: 16, color: AppTheme.textSecondary),
                    ],
                  ),
                ),
          actions: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Row(
                  children: [
                    const Icon(Icons.timer_rounded, size: 16, color: AppTheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      '$minutes:$seconds',
                      style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
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
                                    exercise: ExerciseModel(id: entry.key, name: exerciseName, targetMuscle: ''), // Mock exercise for ID and name
                                  ),
                                );
                              },
                              icon: const Icon(Icons.add_rounded, size: 16),
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
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => const AddExerciseSheet(),
                        );
                      },
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text('ADD EXERCISE'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Sticky Finish Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
              ),
              child: SafeArea(
                child: ElevatedButton(
                  onPressed: state.isLoading ? null : _finishWorkout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: state.isLoading 
                    ? const CircularProgressIndicator(color: Colors.black)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.flag_rounded),
                          const SizedBox(width: 8),
                          const Text('FINISH WORKOUT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2)),
                        ],
                      ),
                ),
              ),
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
        color: AppTheme.error.withValues(alpha: 0.2),
        child: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
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
                color: set.setType == 'dropset' ? Colors.orange.withValues(alpha: 0.2) : (set.setType == 'warmup' ? Colors.blue.withValues(alpha: 0.2) : Colors.transparent),
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
            const Icon(Icons.arrow_back_rounded, size: 16, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}

class _FinishWorkoutSummarySheet extends ConsumerWidget {
  final BuildContext parentContext;

  const _FinishWorkoutSummarySheet({required this.parentContext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(liveSessionControllerProvider);
    final draft = state.draft;

    if (draft == null) return const SizedBox();

    final exercisesCount = draft.sets.map((s) => s.exerciseId).toSet().length;
    final minutes = draft.isLive ? state.elapsedTime.inMinutes : (draft.durationMinutes ?? 0);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded, color: AppTheme.primary, size: 28),
              const SizedBox(width: 12),
              Text('Workout Summary', style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
          const SizedBox(height: 8),
          Text(draft.title, style: const TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat('Duration', '$minutes m'),
              _buildStat('Exercises', '$exercisesCount'),
              _buildStat('Total Sets', '${draft.sets.length}'),
            ],
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: state.isLoading ? null : () async {
              final success = await ref.read(liveSessionControllerProvider.notifier).finishWorkout();
              if (success) {
                await NotificationManager.cancelWorkoutNotification();
                if (parentContext.mounted) {
                  parentContext.showSuccessFlash('Workout saved successfully!');
                  Navigator.pop(parentContext); // close live session page (sheet auto-closes with it)
                }
              } else {
                final error = ref.read(liveSessionControllerProvider).error ?? 'Failed to save workout';
                if (context.mounted) {
                  Navigator.pop(context); // close sheet
                }
                if (parentContext.mounted) {
                  parentContext.showErrorFlash(error);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: state.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                  )
                : const Text('SAVE WORKOUT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(liveSessionControllerProvider.notifier).discardDraft();
              NotificationManager.cancelWorkoutNotification();
              parentContext.showSuccessFlash('Workout session discarded.');
              Navigator.pop(parentContext);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Discard Session'),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      ],
    );
  }
}
