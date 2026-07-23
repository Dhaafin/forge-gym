import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/flash_message.dart';
import '../../../../core/widgets/forge_search_bar.dart';
import '../../../../core/widgets/forge_skeleton.dart';
import '../../controllers/workout_history_controller.dart';
import '../../models/workout_session_model.dart';
import '../workout_session_detail_page.dart';

class WorkoutHistoryView extends ConsumerStatefulWidget {
  final bool isActive;
  const WorkoutHistoryView({super.key, required this.isActive});

  @override
  ConsumerState<WorkoutHistoryView> createState() => _WorkoutHistoryViewState();
}

class _WorkoutHistoryViewState extends ConsumerState<WorkoutHistoryView> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  bool _localLoading = false;
  int _activeRequests = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(workoutHistoryControllerProvider.notifier).resetSortToNewest();
    });
    _triggerLocalLoading();
  }

  @override
  void didUpdateWidget(WorkoutHistoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      ref.read(workoutHistoryControllerProvider.notifier).resetSortToNewest();
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

  void _showSortSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final currentSort = ref.watch(workoutHistoryControllerProvider).selectedSortOption;
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Sort Workout History',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...WorkoutSortOption.values.map((option) {
                final isSelected = currentSort == option;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primary.withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primary
                          : Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: ListTile(
                    leading: Icon(
                      option.sortBy == 'duration_minutes'
                          ? Icons.timer_rounded
                          : option.sortBy == 'sets_count'
                              ? Icons.repeat_rounded
                              : option.order == 'asc'
                                  ? Icons.update_rounded
                                  : Icons.history_rounded,
                      color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                    ),
                    title: Text(
                      option.label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.textPrimary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: AppTheme.primary)
                        : null,
                    onTap: () {
                      ref
                          .read(workoutHistoryControllerProvider.notifier)
                          .setSortOption(option);
                      Navigator.pop(sheetContext);
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(workoutHistoryControllerProvider);
    final displaySessions = historyState.displaySessions;
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

        // ── Filter & Sort Bar ──
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: SizedBox(
            height: 40,
            child: Row(
              children: [
                Expanded(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    children: ['All', 'This Month', 'This Year'].map((filter) {
                      final isSelected = historyState.selectedDateFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(filter),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              ref
                                  .read(workoutHistoryControllerProvider.notifier)
                                  .setDateFilter(filter);
                            }
                          },
                          selectedColor: AppTheme.primary,
                          backgroundColor: AppTheme.surface,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.black : AppTheme.textPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected
                                  ? AppTheme.primary
                                  : Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                          showCheckmark: false,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Material(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showSortSheet(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: historyState.selectedSortOption != WorkoutSortOption.newest
                                ? AppTheme.primary
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.tune_rounded,
                              size: 18,
                              color: historyState.selectedSortOption != WorkoutSortOption.newest
                                  ? AppTheme.primary
                                  : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              historyState.selectedSortOption.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: historyState.selectedSortOption != WorkoutSortOption.newest
                                    ? AppTheme.primary
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Content ──
        Expanded(
          child: showSkeleton
              ? _buildWorkoutsSkeleton()
              : historyState.errorMessage != null && displaySessions.isEmpty
                  ? _buildError(historyState.errorMessage!)
                  : displaySessions.isEmpty
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
                            itemCount: displaySessions.length +
                                (historyState.isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == displaySessions.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                        color: AppTheme.primary),
                                  ),
                                );
                              }
                              return _buildSessionCard(displaySessions[index]);
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
    final prCount = session.prCount;
    final totalVol = session.totalVolume;
    final muscleColor = session.dominantMuscleColor;
    final muscleIcon = session.dominantMuscleIcon;
    final imagePath = session.dominantMuscleImagePath;
    final exercises = session.uniqueExerciseNames;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // 1. Right-Aligned Background Image
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 150,
              child: Image.asset(
                imagePath,
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
                errorBuilder: (_, __, ___) => Image.asset(
                  'assets/images/gym_silhouette.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                ),
              ),
            ),
            // 2. Faded Gradient Mask (Solid surface color on left, fading to transparent on right)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.surface,
                      AppTheme.surface.withValues(alpha: 0.95),
                      AppTheme.surface.withValues(alpha: 0.65),
                      AppTheme.surface.withValues(alpha: 0.10),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ),
            // 3. Card Content
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WorkoutSessionDetailPage(sessionId: session.id),
                    ),
                  );
                },
                splashColor: muscleColor.withValues(alpha: 0.08),
                highlightColor: muscleColor.withValues(alpha: 0.04),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      // Leading Dynamic Icon Badge
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: muscleColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: muscleColor.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          muscleIcon,
                          color: muscleColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title + PR trophy badge if any
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    session.title,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (prCount > 0) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.emoji_events_rounded,
                                          color: Color(0xFFFFD700),
                                          size: 11,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          '$prCount PR${prCount > 1 ? \'s\' : \'\'}',
                                          style: const TextStyle(
                                            color: Color(0xFFFFD700),
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Exercises list preview
                            if (exercises.isNotEmpty) ...[
                              Text(
                                exercises.join(' • '),
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                            ] else ...[
                              const SizedBox(height: 4),
                            ],
                            // Chips Row
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _buildChip(Icons.calendar_today_rounded, date),
                                _buildChip(Icons.timer_rounded, duration),
                                if (setCount > 0)
                                  _buildChip(Icons.repeat_rounded, '$setCount sets'),
                                if (totalVol > 0)
                                  _buildChip(Icons.bolt_rounded, '${totalVol.toInt()} kg'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: muscleColor,
                        size: 20,
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

extension _WorkoutSessionModelExtension on WorkoutSessionModel {
  double get totalVolume {
    return sets.fold(0.0, (sum, set) => sum + (set.weightKg * set.reps));
  }

  int get prCount {
    return sets.where((set) => set.isPr).length;
  }

  List<String> get uniqueExerciseNames {
    final names = <String>[];
    for (var set in sets) {
      if (!names.contains(set.exerciseName)) {
        names.add(set.exerciseName);
      }
    }
    return names;
  }

  String get dominantMuscleGroup {
    if (sets.isEmpty) return 'Full Body';
    final counts = <String, int>{};
    for (var set in sets) {
      final name = set.exerciseName.toLowerCase();
      String muscle = 'Full Body';
      
      if (name.contains('chest') || name.contains('bench') || name.contains('fly') || name.contains('push')) {
        muscle = 'Chest';
      } else if (name.contains('back') || name.contains('row') || name.contains('lat') || name.contains('pull') || name.contains('deadlift')) {
        muscle = 'Back';
      } else if (name.contains('leg') || name.contains('squat') || name.contains('curl') || name.contains('press') || name.contains('calf') || name.contains('lunge')) {
        muscle = 'Legs';
      } else if (name.contains('shoulder') || name.contains('delt') || name.contains('raise') || name.contains('overhead')) {
        muscle = 'Shoulders';
      } else if (name.contains('arm') || name.contains('bicep') || name.contains('tricep') || name.contains('extension')) {
        muscle = 'Arms';
      } else if (name.contains('core') || name.contains('ab') || name.contains('plank') || name.contains('crunch')) {
        muscle = 'Core';
      } else if (name.contains('cardio') || name.contains('run') || name.contains('bike') || name.contains('treadmill')) {
        muscle = 'Cardio';
      }
      
      counts[muscle] = (counts[muscle] ?? 0) + 1;
    }

    if (counts.isEmpty) return 'Full Body';
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  String get dominantMuscleImagePath {
    final m = dominantMuscleGroup.toLowerCase();
    if (m.contains('chest')) return 'assets/images/session_chest.png';
    if (m.contains('back')) return 'assets/images/session_back.png';
    if (m.contains('leg')) return 'assets/images/session_legs.png';
    if (m.contains('shoulder')) return 'assets/images/session_shoulders.png';
    if (m.contains('arm')) return 'assets/images/session_arms.png';
    if (m.contains('core')) return 'assets/images/session_core.png';
    if (m.contains('cardio')) return 'assets/images/session_cardio.png';
    return 'assets/images/gym_silhouette.png';
  }

  Color get dominantMuscleColor {
    final m = dominantMuscleGroup.toLowerCase();
    if (m.contains('chest')) return const Color(0xFF00F0FF); // Neon Cyan
    if (m.contains('back')) return AppTheme.primary; // Volt Lime
    if (m.contains('leg')) return const Color(0xFFFF007A); // Neon Pink
    if (m.contains('shoulder')) return const Color(0xFF7000FF); // Neon Purple
    if (m.contains('arm')) return const Color(0xFFFFB800); // Gold / Amber
    if (m.contains('core')) return const Color(0xFF00FF66); // Neon Green
    if (m.contains('cardio')) return const Color(0xFFFF5E00); // Neon Orange
    return AppTheme.primary;
  }

  IconData get dominantMuscleIcon {
    final m = dominantMuscleGroup.toLowerCase();
    if (m.contains('chest') || m.contains('arm')) return Icons.fitness_center_rounded;
    if (m.contains('back')) return Icons.keyboard_double_arrow_up_rounded;
    if (m.contains('leg')) return Icons.sports_gymnastics_rounded;
    if (m.contains('shoulder')) return Icons.upgrade_rounded;
    if (m.contains('core')) return Icons.center_focus_strong_rounded;
    if (m.contains('cardio')) return Icons.directions_run_rounded;
    return Icons.bolt_rounded;
  }
}
