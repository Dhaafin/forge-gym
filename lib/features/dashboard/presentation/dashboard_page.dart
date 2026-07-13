import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/flash_message.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../workout/controllers/exercise_controller.dart';
import '../../workout/controllers/workout_history_controller.dart';
import '../../workout/models/exercise_model.dart';
import '../../workout/models/workout_session_model.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  int _currentIndex = 0;

  final List<String> _titles = ['Dashboard', 'Workouts', 'Exercises', 'Profile'];

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Welcome Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Welcome Back, Athlete!',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: AppTheme.primary,
                          ),
                    ),
                    const Icon(
                      Icons.emoji_events_rounded,
                      color: AppTheme.primary,
                      size: 28,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your consistency is paying off. Ready to crush your goals today?',
                  style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Today\'s Stats',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 16),
          // Stats Row
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.local_fire_department_rounded,
                  label: 'Calories',
                  value: '420 kcal',
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.timer_rounded,
                  label: 'Duration',
                  value: '45 mins',
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Today's Activity Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Today\'s Schedule',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildActivityItem('Leg Day Workout', '08:00 AM - 09:30 AM', true),
                _buildActivityItem('Post-Workout Meal', '10:00 AM', false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String title, String time, bool isCompleted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: isCompleted ? AppTheme.primary : AppTheme.textSecondary,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
              Text(time, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutsTab() {
    return const _WorkoutHistoryView();
  }

  Widget _buildExercisesTab() {
    return const _ExercisesLibraryView();
  }

  Widget _buildProfileTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.account_circle_rounded, size: 96, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          const Text(
            'Dhaafin',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const Text(
            'Member since July 2026',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error.withValues(alpha: 0.1),
              foregroundColor: AppTheme.error,
              side: const BorderSide(color: AppTheme.error, width: 1),
            ),
            onPressed: () {
              ref.read(authControllerProvider.notifier).logout();
            },
            child: const Text('LOG OUT'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _buildDashboardTab(),
      _buildWorkoutsTab(),
      _buildExercisesTab(),
      _buildProfileTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
      ),
      body: tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: AppTheme.textSecondary,
        backgroundColor: AppTheme.surface,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            label: 'Workouts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center_rounded),
            label: 'Exercises',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _ExercisesLibraryView extends ConsumerStatefulWidget {
  const _ExercisesLibraryView();

  @override
  ConsumerState<_ExercisesLibraryView> createState() => _ExercisesLibraryViewState();
}

class _ExercisesLibraryViewState extends ConsumerState<_ExercisesLibraryView> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(exerciseControllerProvider.notifier).fetchNextPage();
    }
  }

  void _showExerciseForm(BuildContext parentContext, [ExerciseModel? exercise]) {
    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return _ExerciseFormSheet(
          exercise: exercise,
          ref: ref,
          parentContext: parentContext,
        );
      },
    );
  }

  void _showCardActions(BuildContext parentContext, ExerciseModel exercise) {
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
                title: const Text('Edit Exercise'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showExerciseForm(parentContext, exercise);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: AppTheme.error),
                title: const Text('Delete Exercise', style: TextStyle(color: AppTheme.error)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDelete(parentContext, exercise);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext parentContext, ExerciseModel exercise) {
    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Delete Exercise'),
          content: Text('Are you sure you want to delete "${exercise.name}"? This action cannot be undone if this exercise has historical logs.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCEL', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await ref.read(exerciseControllerProvider.notifier).deleteExercise(exercise.id);
                  if (parentContext.mounted) {
                    parentContext.showSuccessFlash('Exercise deleted successfully');
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(exerciseControllerProvider);
    final muscles = ['All', 'Chest', 'Back', 'Legs', 'Arms', 'Shoulders'];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search exercise...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: AppTheme.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(exerciseControllerProvider.notifier).setSearch('');
                        },
                      )
                    : null,
              ),
              onChanged: (val) {
                setState(() {});
              },
              onSubmitted: (val) {
                ref.read(exerciseControllerProvider.notifier).setSearch(val.trim());
              },
            ),
          ),

          // Muscle filter pills
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              itemCount: muscles.length,
              itemBuilder: (context, index) {
                final muscle = muscles[index];
                final isSelected = state.selectedMuscle == muscle;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ChoiceChip(
                    label: Text(muscle),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        ref.read(exerciseControllerProvider.notifier).setMuscleGroup(muscle);
                        _searchController.clear();
                      }
                    },
                    selectedColor: AppTheme.primary,
                    backgroundColor: AppTheme.surface,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : AppTheme.textPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? AppTheme.primary : Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    showCheckmark: false,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Exercise Grid
          Expanded(
            child: state.isLoadingFirst
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : state.errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 48),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                              child: Text(
                                state.errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppTheme.textSecondary),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(minimumSize: const Size(120, 40)),
                              onPressed: () => ref.read(exerciseControllerProvider.notifier).fetchFirstPage(),
                              child: const Text('Try Again'),
                            ),
                          ],
                        ),
                      )
                    : state.exercises.isEmpty
                        ? const Center(
                            child: Text(
                              'No exercises found.',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          )
                        : GridView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16.0),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 1.2,
                            ),
                            itemCount: state.exercises.length + (state.isLoadingMore ? 2 : 0),
                            itemBuilder: (context, index) {
                              if (index >= state.exercises.length) {
                                return _buildSkeletonCard();
                              }
                              final exercise = state.exercises[index];
                              return _buildExerciseCard(exercise);
                            },
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.black,
        onPressed: () => _showExerciseForm(context),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildExerciseCard(ExerciseModel exercise) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.03),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  exercise.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _showCardActions(context, exercise),
                child: const Icon(
                  Icons.more_vert_rounded,
                  color: AppTheme.textSecondary,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              exercise.targetMuscle.toUpperCase(),
              style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            height: 16,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Container(
            height: 20,
            width: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
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
                color: _isExpanded ? AppTheme.primary : Colors.white.withValues(alpha: 0.1),
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
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                              color: isSelected ? AppTheme.primary : Colors.white.withValues(alpha: 0.1),
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

class _ExerciseFormSheet extends StatefulWidget {
  final ExerciseModel? exercise;
  final WidgetRef ref;
  final BuildContext parentContext;

  const _ExerciseFormSheet({
    this.exercise,
    required this.ref,
    required this.parentContext,
  });

  @override
  State<_ExerciseFormSheet> createState() => _ExerciseFormSheetState();
}

class _ExerciseFormSheetState extends State<_ExerciseFormSheet> {
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
                                await widget.ref.read(exerciseControllerProvider.notifier).createExercise(
                                      _nameController.text.trim(),
                                      _selectedMuscle,
                                    );
                                if (widget.parentContext.mounted) {
                                  widget.parentContext.showSuccessFlash('Exercise created successfully');
                                }
                              } else {
                                await widget.ref.read(exerciseControllerProvider.notifier).updateExercise(
                                      widget.exercise!.id,
                                      _nameController.text.trim(),
                                      _selectedMuscle,
                                    );
                                if (widget.parentContext.mounted) {
                                  widget.parentContext.showSuccessFlash('Exercise updated successfully');
                                }
                              }
                              if (context.mounted) Navigator.pop(context);
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
                  color: Colors.black.withValues(alpha: 0.65),
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

// ─────────────────────────────────────────────────────────────
//  WORKOUT HISTORY VIEW
// ─────────────────────────────────────────────────────────────

class _WorkoutHistoryView extends ConsumerStatefulWidget {
  const _WorkoutHistoryView();

  @override
  ConsumerState<_WorkoutHistoryView> createState() => _WorkoutHistoryViewState();
}

class _WorkoutHistoryViewState extends ConsumerState<_WorkoutHistoryView> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final Set<String> _expandedIds = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
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

    return Column(
      children: [
        // ── Search Bar ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: TextField(
            controller: _searchController,
            onChanged: (v) =>
                ref.read(workoutHistoryControllerProvider.notifier).setSearch(v),
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search workouts...',
              prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                      onPressed: () {
                        _searchController.clear();
                        ref
                            .read(workoutHistoryControllerProvider.notifier)
                            .setSearch('');
                        setState(() {});
                      },
                    )
                  : null,
            ),
          ),
        ),

        // ── Content ──
        Expanded(
          child: historyState.isLoadingFirst
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                )
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
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
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
                  final i = entry.key;
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
            child: const Icon(
              Icons.history_rounded,
              color: AppTheme.primary,
              size: 40,
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
              onPressed: () =>
                  ref.read(workoutHistoryControllerProvider.notifier).fetchFirstPage(),
              icon: const Icon(Icons.refresh_rounded, color: AppTheme.primary),
              label: const Text('Retry', style: TextStyle(color: AppTheme.primary)),
            ),
          ],
        ),
      ),
    );
  }
}
