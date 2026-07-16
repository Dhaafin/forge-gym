import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/flash_message.dart';
import '../../../../core/widgets/forge_search_bar.dart';
import '../../../../core/widgets/forge_skeleton.dart';
import '../../controllers/workout_history_controller.dart';
import '../../models/workout_session_model.dart';

class WorkoutHistoryView extends ConsumerStatefulWidget {
  final bool isActive;
  const WorkoutHistoryView({super.key, required this.isActive});

  @override
  ConsumerState<WorkoutHistoryView> createState() => _WorkoutHistoryViewState();
}

class _WorkoutHistoryViewState extends ConsumerState<WorkoutHistoryView> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final Set<String> _expandedIds = {};
  bool _localLoading = false;
  int _activeRequests = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _triggerLocalLoading();
  }

  @override
  void didUpdateWidget(WorkoutHistoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _triggerLocalLoading();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
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

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(workoutHistoryControllerProvider.notifier).fetchNextPage();
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

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(workoutHistoryControllerProvider);
    final showSkeleton = historyState.isLoadingFirst || _localLoading;

    return Column(
      children: [
        // ── Search Bar ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 12.0),
          child: ForgeSearchBar(
            controller: _searchController,
            hintText: 'Search workouts...',
            onChanged: (v) {
              _loadData(() {
                ref.read(workoutHistoryControllerProvider.notifier).setSearch(v);
              });
            },
            onClear: () {
              _loadData(() {
                ref
                    .read(workoutHistoryControllerProvider.notifier)
                    .setSearch('');
              });
            },
          ),
        ),

        // ── Content ──
        Expanded(
          child: showSkeleton
              ? _buildWorkoutsSkeleton()
              : historyState.errorMessage != null && historyState.sessions.isEmpty
                  ? _buildError(historyState.errorMessage!)
                  : historyState.sessions.isEmpty
                      ? _buildEmpty()
                      : RefreshIndicator(
                          color: AppTheme.primary,
                          backgroundColor: AppTheme.surface,
                          onRefresh: () => ref
                              .read(workoutHistoryControllerProvider.notifier)
                              .fetchFirstPage(),
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 24.0),
                            itemCount: historyState.sessions.length +
                                (historyState.isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == historyState.sessions.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                        color: AppTheme.primary),
                                  ),
                                );
                              }
                              return _buildSessionCard(historyState.sessions[index]);
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildSessionCard(WorkoutSessionModel session) {
    final date = _formatDate(session.startDateTime);
    final duration = _formatDuration(session.durationMinutes);
    final setCount = session.sets.length;
    final isExpanded = _expandedIds.contains(session.id);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded
              ? AppTheme.primary.withValues(alpha: 0.35)
              : AppTheme.primary.withValues(alpha: 0.08),
          width: isExpanded ? 1.5 : 1,
        ),
        boxShadow: isExpanded
            ? [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedIds.remove(session.id);
              } else {
                _expandedIds.add(session.id);
              }
            });
          },
          splashColor: AppTheme.primary.withValues(alpha: 0.06),
          highlightColor: AppTheme.primary.withValues(alpha: 0.03),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isExpanded
                            ? AppTheme.primary.withValues(alpha: 0.18)
                            : AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        color: AppTheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.title,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _buildChip(Icons.calendar_today_rounded, date),
                              const SizedBox(width: 10),
                              _buildChip(Icons.timer_rounded, duration),
                              if (setCount > 0) ...[
                                const SizedBox(width: 10),
                                _buildChip(Icons.repeat_rounded, '$setCount sets'),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.more_vert_rounded,
                            color: AppTheme.textSecondary,
                            size: 20,
                          ),
                          onPressed: () => _showSessionActions(context, session),
                        ),
                        const SizedBox(width: 8),
                        AnimatedRotation(
                          turns: isExpanded ? 0.25 : 0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: const Icon(
                            Icons.chevron_right_rounded,
                            color: AppTheme.primary,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeInOut,
                child: isExpanded ? _buildDetailPanel(session) : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSessionActions(BuildContext parentContext, WorkoutSessionModel session) {
    showModalBottomSheet(
      context: parentContext,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: AppTheme.textPrimary),
                title: const Text('Edit Workout Session'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showEditSessionDialog(parentContext, session);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: AppTheme.error),
                title: const Text('Delete Workout Session', style: TextStyle(color: AppTheme.error)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDeleteSession(parentContext, session);
                },
              ),
            ],
          ),
        );
      },
    );
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
                Navigator.pop(dialogContext);
                try {
                  await ref.read(workoutHistoryControllerProvider.notifier).deleteSession(session.id);
                  if (parentContext.mounted) {
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

  Widget _buildDetailPanel(WorkoutSessionModel session) {
    final timeStyle = const TextStyle(color: AppTheme.textSecondary, fontSize: 13);
    final labelStyle = const TextStyle(
      color: AppTheme.textPrimary,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
    );

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Divider
        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: 18),
          color: AppTheme.primary.withValues(alpha: 0.12),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time range row
              if (startStr != null)
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailTile(
                        label: 'START',
                        value: startStr,
                        icon: Icons.play_circle_outline_rounded,
                      ),
                    ),
                    if (endStr != null) ...
                      [
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDetailTile(
                            label: 'END',
                            value: endStr,
                            icon: Icons.stop_circle_outlined,
                          ),
                        ),
                      ],
                    if (session.durationMinutes != null) ...
                      [
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

              // Sets section
              if (session.sets.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('SETS', style: labelStyle),
                const SizedBox(height: 10),
                ...session.sets.asMap().entries.map((entry) {
                  final set = entry.value;
                  final String setLabel = [
                    set.exerciseName,
                    '${set.reps} reps',
                    '${set.weightKg} kg',
                    if (set.setType != 'normal') set.setType.toUpperCase(),
                  ].join(' · ');

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(10),
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            setLabel,
                            style: timeStyle,
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          style: const ButtonStyle(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
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
                                  Icon(Icons.delete_rounded, color: AppTheme.error, size: 16),
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
              ] else ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: AppTheme.textSecondary,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'No set details recorded.',
                      style: timeStyle,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
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

  Widget _buildDetailTile({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.textSecondary, size: 12),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 12),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Workouts Yet',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your completed workout sessions\nwill appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, color: AppTheme.error, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message.replaceAll('Exception: ', ''),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () => _loadData(() {
                ref.read(workoutHistoryControllerProvider.notifier).fetchFirstPage();
              }),
              icon: const Icon(Icons.refresh_rounded, color: AppTheme.primary),
              label: const Text('Retry', style: TextStyle(color: AppTheme.primary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutsSkeleton() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 24.0),
      itemCount: 5,
      itemBuilder: (context, index) {
        return _buildWorkoutSkeletonCard();
      },
    );
  }

  Widget _buildWorkoutSkeletonCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: ForgeSkeleton(
                height: 24,
                width: 24,
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ForgeSkeleton(height: 16, width: 140),
                SizedBox(height: 10),
                Row(
                  children: [
                    ForgeSkeleton(height: 14, width: 70),
                    SizedBox(width: 10),
                    ForgeSkeleton(height: 14, width: 60),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const ForgeSkeleton(height: 16, width: 16),
        ],
      ),
    );
  }
}
