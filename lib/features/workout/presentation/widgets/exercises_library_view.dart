import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/flash_message.dart';
import '../../../../core/widgets/forge_search_bar.dart';
import '../../../../core/widgets/forge_skeleton.dart';
import '../../controllers/exercise_controller.dart';
import '../../models/exercise_model.dart';

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
