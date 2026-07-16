import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/flash_message.dart';
import '../../../../core/widgets/forge_skeleton.dart';
import '../controllers/workout_history_controller.dart';
import '../models/workout_session_model.dart';
import '../controllers/ai_coach_controller.dart';

class WorkoutSessionDetailPage extends ConsumerStatefulWidget {
  final String sessionId;
  const WorkoutSessionDetailPage({super.key, required this.sessionId});

  @override
  ConsumerState<WorkoutSessionDetailPage> createState() => _WorkoutSessionDetailPageState();
}

class _WorkoutSessionDetailPageState extends ConsumerState<WorkoutSessionDetailPage> {
  bool _localLoading = false;
  int _activeRequests = 0;

  @override
  void initState() {
    super.initState();
    _triggerLocalLoading();
  }

  void _triggerLocalLoading() {
    _loadData(() {});
  }

  void _loadData(VoidCallback action) async {
    setState(() {
      _localLoading = true;
      _activeRequests++;
    });

    final currentRequestId = _activeRequests;
    action();

    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted && currentRequestId == _activeRequests) {
      setState(() {
        _localLoading = false;
      });
    }
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatDuration(int? minutes) {
    if (minutes == null) return '—';
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  void _showEditSessionDialog(BuildContext parentContext, WorkoutSessionModel session) {
    showGeneralDialog(
      context: parentContext,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final titleController = TextEditingController(text: session.title);
        final durationController = TextEditingController(text: (session.durationMinutes ?? 0).toString());
        bool isSaving = false;

        return StatefulBuilder(
          builder: (stContext, setState) {
            return Scaffold(
              backgroundColor: AppTheme.background,
              appBar: AppBar(
                title: const Text('Edit Workout Session'),
                leading: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
                actions: [
                  if (isSaving)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2),
                        ),
                      ),
                    )
                  else
                    TextButton(
                      onPressed: () async {
                        final title = titleController.text.trim();
                        final duration = int.tryParse(durationController.text) ?? 0;
                        if (title.isEmpty) return;

                        setState(() {
                          isSaving = true;
                        });

                        try {
                          await ref
                              .read(workoutHistoryControllerProvider.notifier)
                              .updateSession(session.id, title, duration);
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          if (parentContext.mounted) {
                            parentContext.showSuccessFlash('Workout session updated');
                          }
                        } catch (e) {
                          setState(() {
                            isSaving = false;
                          });
                          if (parentContext.mounted) {
                            parentContext.showErrorFlash(e.toString().replaceAll('Exception: ', ''));
                          }
                        }
                      },
                      child: const Text('SAVE', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Session Details',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Modify the workout name and tracked duration.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Workout Title',
                        hintText: 'e.g. Morning Push Workout',
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: durationController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Duration (Minutes)',
                        hintText: 'e.g. 60',
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteSession(BuildContext parentContext, WorkoutSessionModel session) {
    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Delete Workout Session'),
          content: Text('Are you sure you want to delete "${session.title}"? This will permanently delete the session and all its sets.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCEL', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext); // Close dialog
                try {
                  await ref.read(workoutHistoryControllerProvider.notifier).deleteSession(session.id);
                  if (parentContext.mounted) {
                    Navigator.pop(parentContext); // Pop the detail page itself
                    parentContext.showSuccessFlash('Workout session deleted');
                  }
                } catch (e) {
                  if (parentContext.mounted) {
                    parentContext.showErrorFlash(e.toString().replaceAll('Exception: ', ''));
                  }
                }
              },
              child: const Text('DELETE', style: TextStyle(color: AppTheme.error)),
            ),
          ],
        );
      },
    );
  }

  void _showEditSetSheet(BuildContext parentContext, String sessionId, WorkoutSetModel set) {
    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final repsController = TextEditingController(text: set.reps.toString());
        final weightController = TextEditingController(text: set.weightKg.toString());
        String selectedType = set.setType;
        bool isSaving = false;

        return StatefulBuilder(
          builder: (stContext, setState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(sheetContext).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Edit Set for ${set.exerciseName}',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: weightController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: AppTheme.textPrimary),
                          decoration: const InputDecoration(
                            labelText: 'Weight (kg)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: repsController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: AppTheme.textPrimary),
                          decoration: const InputDecoration(
                            labelText: 'Reps',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    dropdownColor: AppTheme.surface,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Set Type',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'normal', child: Text('Normal Set')),
                      DropdownMenuItem(value: 'warmup', child: Text('Warmup Set')),
                      DropdownMenuItem(value: 'dropset', child: Text('Drop Set')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          selectedType = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final reps = int.tryParse(repsController.text) ?? 0;
                              final weight = double.tryParse(weightController.text) ?? 0.0;
                              setState(() {
                                isSaving = true;
                              });

                              try {
                                await ref
                                    .read(workoutHistoryControllerProvider.notifier)
                                    .updateSet(sessionId, set.id, weight, reps, selectedType);
                                if (sheetContext.mounted) {
                                  Navigator.pop(sheetContext);
                                }
                                if (parentContext.mounted) {
                                  parentContext.showSuccessFlash('Set updated successfully');
                                }
                              } catch (e) {
                                setState(() {
                                  isSaving = false;
                                });
                                if (parentContext.mounted) {
                                  parentContext.showErrorFlash(e.toString().replaceAll('Exception: ', ''));
                                }
                              }
                            },
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                            )
                          : const Text('SAVE SET'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteSet(BuildContext parentContext, String sessionId, WorkoutSetModel set) {
    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Delete Set'),
          content: Text('Are you sure you want to delete set ${set.setNumber} for ${set.exerciseName}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCEL', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await ref.read(workoutHistoryControllerProvider.notifier).deleteSet(sessionId, set.id);
                  if (parentContext.mounted) {
                    parentContext.showSuccessFlash('Set deleted successfully');
                  }
                } catch (e) {
                  if (parentContext.mounted) {
                    parentContext.showErrorFlash(e.toString().replaceAll('Exception: ', ''));
                  }
                }
              },
              child: const Text('DELETE', style: TextStyle(color: AppTheme.error)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTile({required String label, required String value, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(workoutHistoryControllerProvider);
    final session = historyState.sessions.firstWhere(
      (s) => s.id == widget.sessionId,
      orElse: () => WorkoutSessionModel(
        id: widget.sessionId,
        userId: '',
        title: 'Workout Session',
        startTime: DateTime.now().toIso8601String(),
        sets: [],
      ),
    );

    final totalVolume = session.sets.fold<double>(
      0.0,
      (sum, set) => sum + (set.weightKg * set.reps),
    );

    final Map<String, List<WorkoutSetModel>> groupedSets = {};
    for (final set in session.sets) {
      groupedSets.putIfAbsent(set.exerciseId, () => []).add(set);
    }

    final date = _formatDate(session.startDateTime);
    final duration = _formatDuration(session.durationMinutes);
    final exerciseCount = groupedSets.keys.length;
    final totalSets = session.sets.length;

    String? formatTime(String? raw) {
      if (raw == null) return null;
      final dt = DateTime.tryParse(raw)?.toLocal();
      if (dt == null) return null;
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }

    final startStr = formatTime(session.startTime);
    final endStr = formatTime(session.endTime);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Edit Session',
            onPressed: () => _showEditSessionDialog(context, session),
          ),
          IconButton(
            icon: const Icon(Icons.delete_rounded, color: AppTheme.error),
            tooltip: 'Delete Session',
            onPressed: () => _confirmDeleteSession(context, session),
          ),
        ],
      ),
      body: _localLoading
          ? _buildDetailPageSkeleton()
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              children: [
          // Title section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.emoji_events_rounded, color: AppTheme.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'CONGRATULATIONS!',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  session.title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Minimalist Row of Icon Badges
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  child: Row(
                    children: [
                      _buildBadge(Icons.calendar_today_rounded, date),
                      const SizedBox(width: 8),
                      _buildBadge(Icons.timer_rounded, duration),
                      const SizedBox(width: 8),
                      _buildBadge(Icons.fitness_center_rounded, '$exerciseCount ex'),
                      const SizedBox(width: 8),
                      _buildBadge(Icons.repeat_rounded, '$totalSets sets'),
                      const SizedBox(width: 8),
                      _buildBadge(Icons.scale_rounded, '${totalVolume.toStringAsFixed(0)} kg'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Time range detail row (if start/end time are available)
          if (startStr != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: _buildDetailTile(
                      label: 'START TIME',
                      value: startStr,
                      icon: Icons.play_circle_outline_rounded,
                    ),
                  ),
                  if (endStr != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDetailTile(
                        label: 'END TIME',
                        value: endStr,
                        icon: Icons.stop_circle_outlined,
                      ),
                    ),
                  ],
                  if (session.durationMinutes != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDetailTile(
                        label: 'DURATION',
                        value: _formatDuration(session.durationMinutes),
                        icon: Icons.timer_outlined,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),
          ],

          _buildAiCoachSection(),

          // Exercises Section Header
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'EXERCISES PERFORMED',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Exercise cards
          if (groupedSets.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Text(
                  'No exercise sets recorded for this session.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            )
          else
            ...groupedSets.entries.map((entry) {
              final exerciseSets = entry.value;
              final exerciseName = exerciseSets.first.exerciseName;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Exercise Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Text(
                        exerciseName.toUpperCase(),
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    // Divider
                    Container(
                      height: 1,
                      color: AppTheme.primary.withValues(alpha: 0.06),
                    ),
                    // Sets List
                    ...exerciseSets.map((set) {
                      final String setLabel = [
                        '${set.reps} reps',
                        '${set.weightKg} kg',
                        if (set.setType != 'normal') set.setType.toUpperCase(),
                      ].join(' · ');

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.white.withValues(alpha: 0.02),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${set.setNumber}',
                                  style: const TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                setLabel,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(
                                Icons.more_vert_rounded,
                                color: AppTheme.textSecondary,
                                size: 18,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onSelected: (action) {
                                if (action == 'edit') {
                                  _showEditSetSheet(context, session.id, set);
                                } else if (action == 'delete') {
                                  _confirmDeleteSet(context, session.id, set);
                                }
                              },
                              itemBuilder: (popContext) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_rounded, size: 16),
                                      SizedBox(width: 8),
                                      Text('Edit Set'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete_rounded,
                                        color: AppTheme.error,
                                        size: 16,
                                      ),
                                      SizedBox(width: 8),
                                      Text('Delete Set', style: TextStyle(color: AppTheme.error)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDetailPageSkeleton() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 24),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const ForgeSkeleton(height: 12, width: 120),
                ],
              ),
              const SizedBox(height: 12),
              const ForgeSkeleton(height: 28, width: 220),
              const SizedBox(height: 20),
              Row(
                children: [
                  _buildBadgeSkeleton(),
                  const SizedBox(width: 8),
                  _buildBadgeSkeleton(),
                  const SizedBox(width: 8),
                  _buildBadgeSkeleton(),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(child: _buildDetailTileSkeleton()),
              const SizedBox(width: 12),
              Expanded(child: _buildDetailTileSkeleton()),
              const SizedBox(width: 12),
              Expanded(child: _buildDetailTileSkeleton()),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: ForgeSkeleton(height: 12, width: 160),
        ),
        const SizedBox(height: 16),
        _buildExerciseCardSkeleton(3),
        _buildExerciseCardSkeleton(2),
      ],
    );
  }

  Widget _buildBadgeSkeleton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ForgeSkeleton(height: 12, width: 12),
          SizedBox(width: 6),
          ForgeSkeleton(height: 12, width: 45),
        ],
      ),
    );
  }

  Widget _buildDetailTileSkeleton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ForgeSkeleton(height: 10, width: 10),
              SizedBox(width: 6),
              ForgeSkeleton(height: 10, width: 50),
            ],
          ),
          SizedBox(height: 8),
          ForgeSkeleton(height: 14, width: 40),
        ],
      ),
    );
  }

  Widget _buildExerciseCardSkeleton(int setLines) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: ForgeSkeleton(height: 14, width: 120),
          ),
          Container(
            height: 1,
            color: AppTheme.primary.withValues(alpha: 0.06),
          ),
          ...List.generate(setLines, (index) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: ForgeSkeleton(height: 10, width: 10),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const ForgeSkeleton(height: 14, width: 110),
                  const Spacer(),
                  const ForgeSkeleton(height: 14, width: 14),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildAiCoachSection() {
    final allStates = ref.watch(aiCoachNotifierProvider);
    final state = allStates[widget.sessionId] ?? AiCoachState();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.smart_toy_rounded, color: AppTheme.primary, size: 18),
              SizedBox(width: 8),
              Text(
                'AI COACH ANALYSIS',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (state.status == AiCoachStatus.idle)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.15),
                    AppTheme.primary.withValues(alpha: 0.05),
                  ],
                ),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    ref.read(aiCoachNotifierProvider.notifier).fetchAnalysis(widget.sessionId);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.auto_awesome_rounded, color: AppTheme.primary, size: 20),
                            SizedBox(width: 10),
                            Text(
                              'ANALYZE WORKOUT WITH AI',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Get personalized overload advice & performance feedback',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else if (state.status == AiCoachStatus.loading)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                state.loadingMessage,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${(state.progress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: state.progress,
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      color: AppTheme.primary,
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            )
          else if (state.status == AiCoachStatus.success && state.data != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.08),
                    Colors.white.withValues(alpha: 0.02),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: AppTheme.primary, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Coach Feedback (${state.data!.modelUsed.split('/').last})',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          ref.read(aiCoachNotifierProvider.notifier).fetchAnalysis(widget.sessionId);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    state.data!.response,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            )
          else if (state.status == AiCoachStatus.error)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.error.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppTheme.error, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Failed to get AI Coach feedback',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          state.errorMessage ?? 'Unknown error occurred',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: AppTheme.primary),
                    onPressed: () => ref.read(aiCoachNotifierProvider.notifier).fetchAnalysis(widget.sessionId),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}
