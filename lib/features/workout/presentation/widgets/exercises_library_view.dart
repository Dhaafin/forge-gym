import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/flash_message.dart';
import '../../../../core/widgets/forge_search_bar.dart';
import '../../../../core/widgets/forge_skeleton.dart';
import '../../controllers/exercise_controller.dart';
import '../../models/exercise_model.dart';
import '../exercise_detail_page.dart';
import 'exercise_form_sheet.dart';

class ExercisesLibraryView extends ConsumerStatefulWidget {
  final bool isActive;
  const ExercisesLibraryView({super.key, required this.isActive});

  @override
  ConsumerState<ExercisesLibraryView> createState() => _ExercisesLibraryViewState();
}

class _ExercisesLibraryViewState extends ConsumerState<ExercisesLibraryView> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  bool _localLoading = false;
  int _activeRequests = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _triggerLocalLoading();
  }

  @override
  void didUpdateWidget(ExercisesLibraryView oldWidget) {
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
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(exerciseControllerProvider.notifier).fetchNextPage();
    }
  }

  void _showExerciseForm(BuildContext parentContext, [ExerciseModel? exercise]) {
    showExerciseFormSheet(parentContext, exercise: exercise);
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
    final muscles = TargetMuscle.filterValues;
    final showSkeleton = state.isLoadingFirst || _localLoading;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 12.0),
            child: ForgeSearchBar(
              controller: _searchController,
              hintText: 'Search exercise...',
              onSubmitted: (val) {
                _loadData(() {
                  ref.read(exerciseControllerProvider.notifier).setSearch(val.trim());
                });
              },
              onClear: () {
                _loadData(() {
                  ref.read(exerciseControllerProvider.notifier).setSearch('');
                });
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
                        _loadData(() {
                          ref.read(exerciseControllerProvider.notifier).setMuscleGroup(muscle);
                        });
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
            child: showSkeleton
                ? _buildExercisesSkeleton()
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
                              onPressed: () => _loadData(() {
                                ref.read(exerciseControllerProvider.notifier).fetchFirstPage();
                              }),
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
                            padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 24.0),
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
        heroTag: 'exercises_library_fab',
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.black,
        onPressed: () => _showExerciseForm(context),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildExerciseCard(ExerciseModel exercise) {
    final muscle = exercise.targetMuscle.toLowerCase();
    String imagePath = 'assets/images/gym_silhouette.png'; // fallback
    if (muscle.contains('chest')) {
      imagePath = 'assets/images/muscles/chest.png';
    } else if (muscle.contains('back')) {
      imagePath = 'assets/images/muscles/back.png';
    } else if (muscle.contains('leg')) {
      imagePath = 'assets/images/muscles/legs.png';
    } else if (muscle.contains('shoulder')) {
      imagePath = 'assets/images/muscles/shoulders.png';
    } else if (muscle.contains('arm')) {
      imagePath = 'assets/images/muscles/arms.png';
    } else if (muscle.contains('core') || muscle.contains('abs')) {
      imagePath = 'assets/images/muscles/core.png';
    } else if (muscle.contains('cardio') || muscle.contains('running')) {
      imagePath = 'assets/images/muscles/cardio.png';
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExerciseDetailPage(exercise: exercise),
        ),
      ),
      child: Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
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
            // 1. Background Image
            Positioned.fill(
              child: Image.asset(
                imagePath,
                fit: BoxFit.cover,
              ),
            ),
            // 2. Dark Gradient Overlay to ensure readability
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            // 3. Card Content
            Padding(
              padding: const EdgeInsets.all(12.0),
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
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                offset: Offset(0, 1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => _showCardActions(context, exercise),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.more_vert_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      exercise.targetMuscle.toUpperCase(),
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildSkeletonCard() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.03),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ForgeSkeleton(height: 16, width: 100),
              SizedBox(height: 6),
              ForgeSkeleton(height: 16, width: 60),
            ],
          ),
          ForgeSkeleton(
            height: 20,
            width: 70,
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ],
      ),
    );
  }

  Widget _buildExercisesSkeleton() {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 24.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: 8,
      itemBuilder: (context, index) {
        return _buildSkeletonCard();
      },
    );
  }
}

