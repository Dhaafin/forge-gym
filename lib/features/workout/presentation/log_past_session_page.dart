import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/flash_message.dart';
import '../../../../core/widgets/forge_search_bar.dart';
import '../../../core/widgets/forge_api_bottom_sheet.dart';
import '../controllers/live_session_controller.dart';
import '../controllers/exercise_controller.dart';
import '../models/workout_session_model.dart';
import '../models/draft_session_model.dart';
import '../models/exercise_model.dart';
import '../services/workout_service.dart';
import 'widgets/add_exercise_sheet.dart';
import 'widgets/add_set_sheet.dart';
import 'widgets/exercise_form_sheet.dart';

class LogPastSessionPage extends ConsumerStatefulWidget {
  final bool isEditing;
  const LogPastSessionPage({super.key, this.isEditing = false});

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

  void _saveSession() async {
    final newSession = await ref.read(liveSessionControllerProvider.notifier).finishWorkout(isEditing: widget.isEditing);
    if (newSession != null) {
      if (mounted) {
        Navigator.pop(context, newSession);
      }
      Future.delayed(const Duration(milliseconds: 300), () {
        ref.read(liveSessionControllerProvider.notifier).resetState();
      });
    } else {
      final error = ref.read(liveSessionControllerProvider).error ?? 'Failed to save session';
      if (mounted) {
        context.showErrorFlash(error);
      }
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
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () {
            ref.read(liveSessionControllerProvider.notifier).discardDraft();
            Navigator.pop(context, false);
          },
        ),
        title: Text(widget.isEditing ? 'Edit Workout Session' : 'Log Past Session', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // AI Note Parser Trigger Card
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        final success = await showModalBottomSheet<bool>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => const _ParseNotesSheet(),
                        );
                        if (success == true && context.mounted) {
                          context.showSuccessFlash('Workout notes parsed and filled!');
                          final draft = ref.read(liveSessionControllerProvider).draft;
                          if (draft != null) {
                            _titleController.text = draft.title;
                          }
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primary.withValues(alpha: 0.15),
                              AppTheme.primary.withValues(alpha: 0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.auto_awesome_rounded,
                                color: AppTheme.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '✨ Auto-fill with AI Notes',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Paste your workout notes to parse instantly.',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.6),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppTheme.primary,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
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
                
                // Beautiful Inline DateTime card
                GestureDetector(
                  onTap: () => _showDateTimeBottomSheet(context, draft),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.date_range_rounded, color: AppTheme.primary),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('WORKOUT SCHEDULE', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('EEEE, dd MMM yyyy').format(draft.startTime),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${DateFormat('HH:mm').format(draft.startTime)} - ${draft.endTime != null ? DateFormat('HH:mm').format(draft.endTime!) : '--:--'} ($calculatedDuration mins)',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.edit_calendar_rounded, color: AppTheme.primary, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                const Text('EXERCISES', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const SizedBox(height: 16),
                
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
                                  style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, letterSpacing: 1.2),
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
                                        exercise: ExerciseModel(id: entry.key, name: exerciseName, targetMuscle: ''),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.add_rounded, size: 16),
                                  label: const Text('Set'),
                                  style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary),
                                  onSelected: (value) async {
                                    if (value == 'swap') {
                                      final selected = await showForgeApiOptionSelector<ExerciseModel>(
                                        context: context,
                                        title: 'Swap Exercise',
                                        subtitle: 'Choose a replacement for $exerciseName',
                                        selectedValue: null,
                                        fetchItems: (query, offset) => ref.read(workoutServiceProvider).fetchExercises(
                                              search: query,
                                              offset: offset,
                                              limit: 10,
                                            ),
                                        labelBuilder: (e) => e.name,
                                        idBuilder: (e) => e.id,
                                        iconBuilder: (e) => Icons.fitness_center_rounded,
                                      );
                                      if (selected != null && context.mounted) {
                                        ref.read(liveSessionControllerProvider.notifier).replaceExercise(
                                          oldExerciseId: entry.key,
                                          newExercise: selected,
                                        );
                                      }
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
          
          // Save Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
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
                        Icon(Icons.save_rounded),
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

  void _showDateTimeBottomSheet(BuildContext context, DraftSessionModel draft) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final state = ref.watch(liveSessionControllerProvider);
            final currentDraft = state.draft!;
            final duration = currentDraft.endTime != null
                ? currentDraft.endTime!.difference(currentDraft.startTime).inMinutes
                : 0;

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.calendar_month_rounded, color: AppTheme.primary, size: 24),
                          SizedBox(width: 8),
                          Text(
                            'Workout Schedule',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white54),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Date Picker Card
                  InkWell(
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: currentDraft.startTime,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: AppTheme.primary,
                                onPrimary: Colors.black,
                                surface: AppTheme.surface,
                                onSurface: Colors.white,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        final newStart = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                          currentDraft.startTime.hour,
                          currentDraft.startTime.minute,
                        );
                        final newEnd = currentDraft.endTime != null
                            ? DateTime(
                                picked.year,
                                picked.month,
                                picked.day,
                                currentDraft.endTime!.hour,
                                currentDraft.endTime!.minute,
                              )
                            : null;
                        ref.read(liveSessionControllerProvider.notifier).updatePastSessionTimes(
                              startTime: newStart,
                              endTime: newEnd,
                            );
                        setModalState(() {});
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, color: AppTheme.primary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('DATE', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('EEEE, dd MMM yyyy').format(currentDraft.startTime),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Start and End Time Rows
                  Row(
                    children: [
                      // Start Time Card
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final TimeOfDay? picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(currentDraft.startTime),
                            );
                            if (picked != null) {
                              final newStart = DateTime(
                                currentDraft.startTime.year,
                                currentDraft.startTime.month,
                                currentDraft.startTime.day,
                                picked.hour,
                                picked.minute,
                              );
                              ref.read(liveSessionControllerProvider.notifier).updatePastSessionTimes(startTime: newStart);
                              setModalState(() {});
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('START TIME', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.play_circle_outline_rounded, color: Colors.green, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormat('HH:mm').format(currentDraft.startTime),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // End Time Card
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final initialEnd = currentDraft.endTime ?? currentDraft.startTime.add(const Duration(hours: 1));
                            final TimeOfDay? picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(initialEnd),
                            );
                            if (picked != null) {
                              final newEnd = DateTime(
                                currentDraft.startTime.year,
                                currentDraft.startTime.month,
                                currentDraft.startTime.day,
                                picked.hour,
                                picked.minute,
                              );
                              ref.read(liveSessionControllerProvider.notifier).updatePastSessionTimes(endTime: newEnd);
                              setModalState(() {});
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('END TIME', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.stop_circle_outlined, color: AppTheme.error, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      currentDraft.endTime != null
                                          ? DateFormat('HH:mm').format(currentDraft.endTime!)
                                          : '--:--',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Calculated Duration Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.timer_rounded, color: AppTheme.primary, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Calculated Duration',
                              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        Text(
                          '$duration mins',
                          style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('CONFIRM', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
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

enum _NotesSheetStage { input, confirm }

class _ParseNotesSheet extends ConsumerStatefulWidget {
  const _ParseNotesSheet();

  @override
  ConsumerState<_ParseNotesSheet> createState() => _ParseNotesSheetState();
}

class _ParseNotesSheetState extends ConsumerState<_ParseNotesSheet> {
  final _notesController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  
  _NotesSheetStage _stage = _NotesSheetStage.input;
  Map<String, dynamic>? _parsedResult;
  List<Map<String, dynamic>> _unmatchedExercises = [];
  final Set<String> _selectedUnmatchedNames = {};
  final Map<String, ExerciseModel> _mappedExercises = {};

  double _loadingProgress = 0.0;
  String _loadingMessage = 'Initializing...';
  Timer? _loadingTimer;

  @override
  void dispose() {
    _notesController.dispose();
    _loadingTimer?.cancel();
    super.dispose();
  }

  void _submit() async {
    final text = _notesController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _loadingProgress = 0.0;
      _loadingMessage = 'Contacting AI...';
    });

    final steps = [
      _LoadingStep(0.0, 0.25, 'Reading workout notes...'),
      _LoadingStep(0.25, 0.55, 'Identifying exercise names...'),
      _LoadingStep(0.55, 0.80, 'Analyzing sets, reps & weights...'),
      _LoadingStep(0.80, 0.95, 'Matching with database...'),
    ];

    _loadingTimer?.cancel();
    _loadingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_loadingProgress < 0.95) {
          _loadingProgress += 0.02;
          if (_loadingProgress > 0.95) _loadingProgress = 0.95;

          for (int i = 0; i < steps.length; i++) {
            if (_loadingProgress >= steps[i].start && _loadingProgress <= steps[i].end) {
              _loadingMessage = steps[i].message;
              break;
            }
          }
        }
      });
    });

    try {
      final service = ref.read(workoutServiceProvider);
      final result = await service.parseWorkoutNotes(text);

      _loadingTimer?.cancel();
      setState(() {
        _loadingProgress = 1.0;
        _loadingMessage = 'Parsing complete!';
      });
      await Future.delayed(const Duration(milliseconds: 250));

      final rawExercises = result['exercises'] as List<dynamic>? ?? [];
      final List<Map<String, dynamic>> unmatched = [];

      for (final rawExercise in rawExercises) {
        final exerciseJson = rawExercise as Map<String, dynamic>;
        final matched = exerciseJson['matched'] as bool? ?? false;
        if (!matched) {
          unmatched.add(exerciseJson);
        }
      }

      if (unmatched.isEmpty) {
        ref.read(liveSessionControllerProvider.notifier).populateFromParsedJson(result);
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        setState(() {
          _isLoading = false;
          _parsedResult = result;
          _unmatchedExercises = unmatched;
          _selectedUnmatchedNames.clear();
          _mappedExercises.clear();
          for (final exercise in unmatched) {
            final rawName = exercise['raw_name'] as String? ?? 'Unnamed';
            _selectedUnmatchedNames.add(rawName);
          }
          _stage = _NotesSheetStage.confirm;
        });
      }
    } catch (e) {
      _loadingTimer?.cancel();
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _confirmAndPopulate() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _loadingProgress = 0.0;
      _loadingMessage = 'Linking exercises...';
    });

    final steps = [
      _LoadingStep(0.0, 0.40, 'Linking to database...'),
      _LoadingStep(0.40, 0.80, 'Creating new exercises if needed...'),
      _LoadingStep(0.80, 0.95, 'Synchronizing notes...'),
    ];

    _loadingTimer?.cancel();
    _loadingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_loadingProgress < 0.95) {
          _loadingProgress += 0.03;
          if (_loadingProgress > 0.95) _loadingProgress = 0.95;

          for (int i = 0; i < steps.length; i++) {
            if (_loadingProgress >= steps[i].start && _loadingProgress <= steps[i].end) {
              _loadingMessage = steps[i].message;
              break;
            }
          }
        }
      });
    });

    try {
      final service = ref.read(workoutServiceProvider);
      final updatedExercises = <Map<String, dynamic>>[];

      final rawExercises = _parsedResult!['exercises'] as List<dynamic>? ?? [];

      for (final rawExercise in rawExercises) {
        final exerciseJson = Map<String, dynamic>.from(rawExercise as Map<String, dynamic>);
        final matched = exerciseJson['matched'] as bool? ?? false;

        if (matched) {
          updatedExercises.add(exerciseJson);
        } else {
          final rawName = exerciseJson['raw_name'] as String? ?? 'Unnamed';
          
          if (_mappedExercises.containsKey(rawName)) {
            final mapped = _mappedExercises[rawName]!;
            exerciseJson['exercise_id'] = mapped.id;
            exerciseJson['exercise_name'] = mapped.name;
            exerciseJson['matched'] = true;
            
            updatedExercises.add(exerciseJson);
          } else if (_selectedUnmatchedNames.contains(rawName)) {
            final targetMuscle = exerciseJson['inferred_target_muscle'] as String? ?? TargetMuscle.fullBody;
            debugPrint('[LiveSession] Confirmed creation of: $rawName ($targetMuscle)');

            final newExercise = await service.createExercise(
              name: rawName,
              targetMuscle: targetMuscle,
            );

            exerciseJson['exercise_id'] = newExercise.id;
            exerciseJson['exercise_name'] = newExercise.name;
            exerciseJson['matched'] = true;

            updatedExercises.add(exerciseJson);
          } else {
            debugPrint('[LiveSession] User skipped creation and mapping of: $rawName. Skipping.');
          }
        }
      }

      final finalResult = Map<String, dynamic>.from(_parsedResult!);
      finalResult['exercises'] = updatedExercises;

      _loadingTimer?.cancel();
      setState(() {
        _loadingProgress = 1.0;
        _loadingMessage = 'Sync successful!';
      });
      await Future.delayed(const Duration(milliseconds: 250));

      ref.read(liveSessionControllerProvider.notifier).populateFromParsedJson(finalResult);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _loadingTimer?.cancel();
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Widget _buildLoadingState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppTheme.primary,
              size: 40,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _loadingMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: _loadingProgress,
            minHeight: 8,
            backgroundColor: AppTheme.surface,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${(_loadingProgress * 100).toInt()}%',
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: AppTheme.primary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildInputStage() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: AppTheme.primary),
            const SizedBox(width: 12),
            Text(
              'Auto-fill with AI Notes',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Paste your workout notes below. AI will automatically parse the exercise name, sets, reps, weight, and date.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
            ),
            child: Text(
              _error!,
              style: const TextStyle(color: AppTheme.error, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _notesController,
          maxLines: 6,
          minLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Example:\n## 06-04-26 (Pull Day)\n- Lat Pulldowns 3 x 12 (30kg)\n- Bicep Curl 3 x 10 (10kg)',
            hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
            filled: true,
            fillColor: AppTheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'PARSE AI NOTES',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildConfirmationStage() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.help_outline_rounded, color: AppTheme.primary),
            const SizedBox(width: 12),
            Text(
              'New Exercises Detected',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'The following exercises were not found in your database. Please link them to existing ones or create them automatically:',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
            ),
            child: Text(
              _error!,
              style: const TextStyle(color: AppTheme.error, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Container(
          constraints: const BoxConstraints(maxHeight: 220),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _unmatchedExercises.length,
            itemBuilder: (context, index) {
              final exercise = _unmatchedExercises[index];
              final rawName = exercise['raw_name'] as String? ?? 'Unnamed';
              final muscle = exercise['inferred_target_muscle'] as String? ?? TargetMuscle.fullBody;
              
              final isMapped = _mappedExercises.containsKey(rawName);

              if (isMapped) {
                final mappedExercise = _mappedExercises[rawName]!;
                return ListTile(
                  title: Text(
                    rawName,
                    style: const TextStyle(
                      color: Colors.white70,
                      decoration: TextDecoration.lineThrough,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    '🔗 Linked to: ${mappedExercise.name}',
                    style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  trailing: TextButton(
                    onPressed: () {
                      setState(() {
                        _mappedExercises.remove(rawName);
                        _selectedUnmatchedNames.add(rawName);
                      });
                    },
                    child: const Text('Change', style: TextStyle(color: AppTheme.primary)),
                  ),
                );
              } else {
                final isChecked = _selectedUnmatchedNames.contains(rawName);
                return ListTile(
                  title: Row(
                    children: [
                      Checkbox(
                        value: isChecked,
                        activeColor: AppTheme.primary,
                        checkColor: Colors.black,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedUnmatchedNames.add(rawName);
                            } else {
                              _selectedUnmatchedNames.remove(rawName);
                            }
                          });
                        },
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rawName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              'Create new (Muscle: $muscle)',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  trailing: TextButton.icon(
                    onPressed: () async {
                      ref.read(exerciseControllerProvider.notifier).setSearch('');
                      
                      final selected = await showModalBottomSheet<ExerciseModel>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const _LinkExerciseSheet(),
                      );
                      if (selected != null) {
                        setState(() {
                          _mappedExercises[rawName] = selected;
                          _selectedUnmatchedNames.remove(rawName);
                        });
                      }
                    },
                    icon: const Icon(Icons.link_rounded, size: 14, color: AppTheme.primary),
                    label: const Text('Link', style: TextStyle(color: AppTheme.primary)),
                  ),
                );
              }
            },
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _stage = _NotesSheetStage.input;
                    _error = null;
                  });
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _confirmAndPopulate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'CREATE & INSERT',
                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: _isLoading 
            ? _buildLoadingState() 
            : (_stage == _NotesSheetStage.input ? _buildInputStage() : _buildConfirmationStage()),
      ),
    );
  }
}

class _LoadingStep {
  final double start;
  final double end;
  final String message;

  _LoadingStep(this.start, this.end, this.message);
}

class _LinkExerciseSheet extends ConsumerStatefulWidget {
  const _LinkExerciseSheet();

  @override
  ConsumerState<_LinkExerciseSheet> createState() => _LinkExerciseSheetState();
}

class _LinkExerciseSheetState extends ConsumerState<_LinkExerciseSheet> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
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
              const Text('Select Registered Exercise', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                child: ForgeSearchBar(
                  controller: _searchController,
                  hintText: 'Search exercise...',
                  onSubmitted: (val) {
                    ref.read(exerciseControllerProvider.notifier).setSearch(val.trim());
                  },
                  onClear: () {
                    ref.read(exerciseControllerProvider.notifier).setSearch('');
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final created = await showExerciseFormSheet(
                      context,
                      initialName: _searchController.text.trim(),
                    );
                    if (created != null && mounted) {
                      Navigator.pop(context, created);
                    }
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create New Exercise'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                    foregroundColor: AppTheme.primary,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppTheme.primary, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: state.isLoadingFirst
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                    : NotificationListener<ScrollNotification>(
                        onNotification: (scrollInfo) {
                          if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
                            ref.read(exerciseControllerProvider.notifier).fetchNextPage();
                          }
                          return false;
                        },
                        child: ListView.builder(
                          controller: controller,
                          itemCount: state.exercises.length + (state.isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= state.exercises.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                              );
                            }
                            final exercise = state.exercises[index];
                            return ListTile(
                              title: Text(exercise.name, style: const TextStyle(color: Colors.white)),
                              subtitle: Text(exercise.targetMuscle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                              trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.primary, size: 16),
                              onTap: () {
                                Navigator.pop(context, exercise);
                              },
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
