import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/flash_message.dart';
import '../controllers/live_session_controller.dart';
import '../models/workout_session_model.dart';
import '../models/exercise_model.dart';
import '../services/workout_service.dart';
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
    final newSession = await ref.read(liveSessionControllerProvider.notifier).finishWorkout();
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
        title: const Text('Log Past Session', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                                    '✨ Auto-fill dengan Catatan AI',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tempel tulisan workout Anda untuk di-parse instan.',
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
                
                Row(
                  children: [
                    Expanded(
                      child: _buildPickerField(
                        label: 'Date',
                        value: DateFormat('dd MMM yyyy').format(draft.startTime),
                        icon: Icons.calendar_today_rounded,
                        onTap: () => _selectDate(context, draft.startTime),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildPickerField(
                        label: 'Duration',
                        value: '$calculatedDuration min',
                        icon: Icons.timer_rounded,
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
                        icon: Icons.access_time_rounded,
                        onTap: () => _selectTime(context, draft.startTime, true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildPickerField(
                        label: 'End Time',
                        value: draft.endTime != null ? DateFormat('HH:mm').format(draft.endTime!) : '--:--',
                        icon: Icons.access_time_rounded,
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
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.save_rounded),
                        const SizedBox(width: 8),
                        const Text('SAVE SESSION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2)),
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

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _submit() async {
    final text = _notesController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(workoutServiceProvider);
      final result = await service.parseWorkoutNotes(text);

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
          for (final exercise in unmatched) {
            final rawName = exercise['raw_name'] as String? ?? 'Unnamed';
            _selectedUnmatchedNames.add(rawName);
          }
          _stage = _NotesSheetStage.confirm;
        });
      }
    } catch (e) {
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
          if (_selectedUnmatchedNames.contains(rawName)) {
            final targetMuscle = exerciseJson['inferred_target_muscle'] as String? ?? 'Other';
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
            debugPrint('[LiveSession] User skipped creation of: $rawName. Skipping exercise.');
          }
        }
      }

      final finalResult = Map<String, dynamic>.from(_parsedResult!);
      finalResult['exercises'] = updatedExercises;

      ref.read(liveSessionControllerProvider.notifier).populateFromParsedJson(finalResult);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
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
              'Auto-fill dengan Catatan AI',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Tempel catatan latihan Anda di bawah. AI akan memilah nama latihan, set, reps, beban, dan tanggal latihan secara otomatis.',
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
            hintText: 'Contoh:\n## 06-04-26 (Pull Day)\n- Lat Pulldowns 3 x 12 (30kg)\n- Bicep Curl 3 x 10 (10kg)',
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
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                )
              : const Text(
                  'PARSE CATATAN AI',
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
              'Latihan Baru Terdeteksi',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Latihan-latihan berikut tidak ditemukan di database Anda. Centang latihan yang ingin Anda buat secara otomatis:',
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
          constraints: const BoxConstraints(maxHeight: 200),
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
              final muscle = exercise['inferred_target_muscle'] as String? ?? 'Other';
              final isChecked = _selectedUnmatchedNames.contains(rawName);

              return CheckboxListTile(
                value: isChecked,
                activeColor: AppTheme.primary,
                checkColor: Colors.black,
                title: Text(
                  rawName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: Text(
                  'Otot target: $muscle',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                onChanged: _isLoading
                    ? null
                    : (val) {
                        setState(() {
                          if (val == true) {
                            _selectedUnmatchedNames.add(rawName);
                          } else {
                            _selectedUnmatchedNames.remove(rawName);
                          }
                        });
                      },
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() {
                          _stage = _NotesSheetStage.input;
                          _error = null;
                        });
                      },
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Batal'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _confirmAndPopulate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                      )
                    : const Text(
                        'BUAT & MASUKKAN',
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
        child: _stage == _NotesSheetStage.input ? _buildInputStage() : _buildConfirmationStage(),
      ),
    );
  }
}
