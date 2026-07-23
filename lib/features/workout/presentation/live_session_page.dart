import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
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

  void _openFinishSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _FinishWorkoutSummarySheet(pageContext: context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(liveSessionControllerProvider);
    final draft = state.draft;

    // Show a spinner only during initial app startup while the draft is
    // being loaded from local storage. Once the draft is available the
    // page renders normally. If there is genuinely no draft the caller
    // should not have navigated here, but we guard gracefully.
    if (draft == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final minutes = state.elapsedTime.inMinutes.toString().padLeft(2, '0');
    final seconds = (state.elapsedTime.inSeconds % 60).toString().padLeft(2, '0');

    final Map<String, List<WorkoutSetModel>> groupedSets = {};
    for (final set in draft.sets) {
      groupedSets.putIfAbsent(set.exerciseId, () => []).add(set);
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        // Session stays active in the background when user presses back.
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
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                  autofocus: true,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Workout Title',
                    hintStyle: TextStyle(color: Colors.white54),
                  ),
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
                      Text(draft.title,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      const Icon(Icons.edit_rounded,
                          size: 16, color: AppTheme.textSecondary),
                    ],
                  ),
                ),
          actions: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Row(
                  children: [
                    const Icon(Icons.timer_rounded,
                        size: 16, color: AppTheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      '$minutes:$seconds',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontFamily: 'monospace',
                      ),
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
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    onReorder: (oldIndex, newIndex) {
                      ref.read(liveSessionControllerProvider.notifier).reorderExercises(oldIndex, newIndex);
                    },
                    children: groupedSets.entries.toList().asMap().entries.map((item) {
                      final index = item.key;
                      final entry = item.value;
                      final exerciseSets = entry.value;
                      final exerciseName = exerciseSets.first.exerciseName;

                      return Column(
                        key: ValueKey(entry.key),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: const Padding(
                                      padding: EdgeInsets.only(right: 8.0),
                                      child: Icon(Icons.drag_handle_rounded, color: AppTheme.textSecondary),
                                    ),
                                  ),
                                  Text(
                                    exerciseName.toUpperCase(),
                                    style: const TextStyle(
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  TextButton.icon(
                                    onPressed: () {
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (context) => AddSetSheet(
                                          exercise: ExerciseModel(
                                            id: entry.key,
                                            name: exerciseName,
                                            targetMuscle: '',
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.add_rounded, size: 16),
                                    label: const Text('Set'),
                                    style: TextButton.styleFrom(
                                        foregroundColor: AppTheme.primary),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary),
                                    onSelected: (value) async {
                                      if (value == 'swap') {
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          backgroundColor: Colors.transparent,
                                          builder: (context) => AddExerciseSheet(
                                            oldExerciseId: entry.key,
                                          ),
                                        );
                                      } else if (value == 'delete') {
                                        ref.read(liveSessionControllerProvider.notifier).deleteExercise(entry.key);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'swap',
                                        child: Row(
                                          children: [
                                            Icon(Icons.swap_horiz_rounded, size: 18),
                                            SizedBox(width: 8),
                                            Text('Swap Exercise'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 18),
                                            SizedBox(width: 8),
                                            Text('Delete Exercise', style: TextStyle(color: AppTheme.error)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          ...exerciseSets.map((set) => _buildSetRow(set)),
                          const SizedBox(height: 24),
                        ],
                      );
                    }).toList(),
                  ),
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
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
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
                border: Border(
                    top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1))),
              ),
              child: SafeArea(
                child: ElevatedButton(
                  onPressed: state.isLoading ? null : _openFinishSheet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: state.isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.flag_rounded),
                            SizedBox(width: 8),
                            Text(
                              'FINISH WORKOUT',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  letterSpacing: 1.2),
                            ),
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
                style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text('${set.weightKg} kg',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  Text('${set.reps} reps',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: set.setType == 'dropset'
                    ? Colors.orange.withValues(alpha: 0.2)
                    : (set.setType == 'warmup'
                        ? Colors.blue.withValues(alpha: 0.2)
                        : Colors.transparent),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                set.setType == 'normal'
                    ? ''
                    : (set.setType == 'warmup' ? 'W' : 'D'),
                style: TextStyle(
                  color: set.setType == 'dropset' ? Colors.orange : Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            const Icon(Icons.arrow_back_rounded,
                size: 16, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary Sheet
// ---------------------------------------------------------------------------

class _FinishWorkoutSummarySheet extends ConsumerWidget {
  /// The [BuildContext] of the LiveSessionPage, captured before the sheet
  /// is pushed so we can pop the page safely and show flash messages on a mounted context.
  final BuildContext pageContext;

  const _FinishWorkoutSummarySheet({required this.pageContext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(liveSessionControllerProvider);
    final draft = state.draft;

    if (draft == null) return const SizedBox.shrink();

    final exercisesCount = draft.sets.map((s) => s.exerciseId).toSet().length;
    final minutes =
        draft.isLive ? state.elapsedTime.inMinutes : (draft.durationMinutes ?? 0);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded,
                  color: AppTheme.primary, size: 28),
              const SizedBox(width: 12),
              Text('Workout Summary',
                  style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
          const SizedBox(height: 8),
          Text(draft.title,
              style: const TextStyle(color: Colors.white70, fontSize: 16)),
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
            onPressed: state.isLoading
                ? null
                : () async {
                    final notifier =
                        ref.read(liveSessionControllerProvider.notifier);
                    final newSession = await notifier.finishWorkout();

                    if (newSession != null) {
                       // 1. Close this sheet.
                       if (context.mounted) Navigator.of(context).pop();
                       
                       // 2. Close the LiveSessionPage returning newSession.
                       if (pageContext.mounted) {
                         Navigator.of(pageContext).pop(newSession);
                       }
                       
                       // 3. Now that the UI has navigated away, wait for animation then reset state.
                       Future.delayed(const Duration(milliseconds: 300), () {
                         notifier.resetState();
                       });
                    } else {
                       final error =
                           ref.read(liveSessionControllerProvider).error ??
                               'Failed to save workout';
                       if (context.mounted) Navigator.of(context).pop();
                       if (pageContext.mounted) {
                         pageContext.showErrorFlash(error);
                       }
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: state.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.black, strokeWidth: 2.5),
                  )
                : const Text('SAVE WORKOUT',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // close sheet
              ref.read(liveSessionControllerProvider.notifier).discardDraft();
              if (pageContext.mounted) {
                Navigator.of(pageContext).pop(false); // pop page returning false
              }
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
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12)),
      ],
    );
  }
}
