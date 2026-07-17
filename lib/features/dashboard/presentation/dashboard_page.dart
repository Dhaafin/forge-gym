import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/flash_message.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../workout/controllers/workout_history_controller.dart';
import '../../workout/models/workout_session_model.dart';
import '../../workout/presentation/widgets/session_mode_picker_sheet.dart';
import '../../workout/presentation/live_session_page.dart';
import '../../workout/presentation/log_past_session_page.dart';
import '../../workout/controllers/live_session_controller.dart';
import '../../../../core/services/notification_manager.dart';
import '../../workout/presentation/widgets/exercises_library_view.dart';
import '../../workout/presentation/widgets/workout_history_view.dart';
import '../../workout/presentation/widgets/analytics_view.dart';
import '../../workout/presentation/workout_session_detail_page.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  int _currentIndex = 0;

  final List<String> _titles = ['Dashboard', 'Workouts', 'Analytics', 'Exercises', 'Profile'];

  Future<void> _navigateToLiveSession() async {
    try {
      await NotificationManager.init();
    } catch (e) {
      debugPrint("Notification Manager init failed: $e");
    }

    final state = ref.read(liveSessionControllerProvider);
    if (state.draft != null) {
      try {
        await NotificationManager.showWorkoutNotification(
          title: state.draft!.title,
          startTime: state.draft!.startTime,
        );
      } catch (e) {
        debugPrint("Local Notification start failed: $e");
      }
    }

    if (!mounted) return;
    final saved = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LiveSessionPage()),
    );

    if (!mounted) return;
    if (saved is WorkoutSessionModel) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WorkoutSessionDetailPage(sessionId: saved.id),
        ),
      );
      if (!mounted) return;
      context.showSuccessFlash('Workout saved successfully!');
    } else if (saved == false) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) context.showSuccessFlash('Workout session discarded.');
    }
  }

  Widget _buildActiveWorkoutBar(LiveSessionState liveSessionState) {
    final draft = liveSessionState.draft!;
    final minutes = liveSessionState.elapsedTime.inMinutes.toString().padLeft(2, '0');
    final seconds = (liveSessionState.elapsedTime.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _navigateToLiveSession,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                    color: AppTheme.primary.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    const _GlowingIndicator(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            draft.title,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Workout in progress...',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.timer_rounded,
                          color: AppTheme.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$minutes:$seconds',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardTab() {
    final historyState = ref.watch(workoutHistoryControllerProvider);
    final userEmail = ref.read(authControllerProvider).value?.split('.').last ?? 'Athlete';

    // Calculate stats
    int workoutsThisWeek = 0;
    int totalVolume = 0;
    
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    for (var session in historyState.sessions) {
      if (session.startDateTime.isAfter(startOfWeek)) {
        workoutsThisWeek++;
      }
      for (var set in session.sets) {
        totalVolume += (set.weightKg * set.reps).toInt();
      }
    }

    final recentSessions = historyState.sessions.take(3).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Welcome Card (Glassmorphism inspired)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.15),
                  AppTheme.primary.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Welcome Back, $userEmail!',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        color: AppTheme.primary,
                        size: 32,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your consistency is paying off. Ready to crush your goals today?',
                  style: TextStyle(color: AppTheme.textSecondary, height: 1.5, fontSize: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          Text(
            'Your Progress',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          // Stats Row
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.fitness_center_rounded,
                  label: 'Total Volume',
                  value: '$totalVolume kg',
                  color: const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.calendar_today_rounded,
                  label: 'This Week',
                  value: '$workoutsThisWeek sessions',
                  color: const Color(0xFF3B82F6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Recent Activity Card
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (historyState.sessions.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _currentIndex = 1; // Go to Workouts tab
                    });
                  },
                  child: const Text('View All', style: TextStyle(color: AppTheme.primary)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (historyState.isLoadingFirst)
            const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          else if (recentSessions.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                children: [
                  Icon(Icons.directions_run_rounded, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  const Text(
                    'No recent workouts',
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Time to hit the gym!',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            )
          else
            ...recentSessions.map((session) => _buildActivityItem(
                  session.title,
                  '${_formatDate(session.startDateTime)} • ${session.durationMinutes ?? 0} mins',
                  true,
                )),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today';
    } else if (date.year == now.year && date.month == now.month && date.day == now.day - 1) {
      return 'Yesterday';
    }
    return '${date.day}/${date.month}/${date.year}';
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

  Widget _buildWorkoutsTab(bool isActive) {
    return WorkoutHistoryView(isActive: isActive);
  }

  Widget _buildExercisesTab(bool isActive) {
    return ExercisesLibraryView(isActive: isActive);
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
      _buildWorkoutsTab(_currentIndex == 1),
      AnalyticsView(isActive: _currentIndex == 2),
      _buildExercisesTab(_currentIndex == 3),
      _buildProfileTab(),
    ];

    final liveSessionState = ref.watch(liveSessionControllerProvider);
    final hasActiveSession = liveSessionState.draft != null && liveSessionState.draft!.isLive;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
      ),
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: tabs,
            ),
          ),
          if (hasActiveSession) _buildActiveWorkoutBar(liveSessionState),
        ],
      ),
      floatingActionButton: (_currentIndex == 1 && !hasActiveSession)
          ? FloatingActionButton(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
              onPressed: () async {
                final mode = await showModalBottomSheet<String>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const SessionModePickerSheet(),
                );

                if (!context.mounted || mode == null) return;

                if (mode == 'live') {
                  ref.read(liveSessionControllerProvider.notifier).startLiveSession();
                  _navigateToLiveSession();
                } else if (mode == 'past') {
                  ref.read(liveSessionControllerProvider.notifier).startPastSession();

                  if (!context.mounted) return;
                  final saved = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LogPastSessionPage()),
                  );

                  if (!context.mounted) return;
                  if (saved is WorkoutSessionModel) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WorkoutSessionDetailPage(sessionId: saved.id),
                      ),
                    );
                    if (!context.mounted) return;
                    context.showSuccessFlash('Past session logged successfully!');
                  } else if (saved == false) {
                    await Future.delayed(const Duration(seconds: 2));
                    if (context.mounted) context.showSuccessFlash('Workout session discarded.');
                  }
                }
              },
              child: const Icon(Icons.add_rounded),
            )
          : null,
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
            icon: Icon(Icons.analytics_rounded),
            label: 'Analytics',
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

class _GlowingIndicator extends StatefulWidget {
  const _GlowingIndicator();

  @override
  State<_GlowingIndicator> createState() => _GlowingIndicatorState();
}

class _GlowingIndicatorState extends State<_GlowingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 3.0, end: 8.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.6),
                blurRadius: _animation.value,
                spreadRadius: _animation.value / 2,
              ),
            ],
          ),
        );
      },
    );
  }
}
