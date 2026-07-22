import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/flash_message.dart';
import '../../../../core/widgets/forge_skeleton.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/controllers/profile_controller.dart';
import '../../auth/models/user_profile_model.dart';
import '../../auth/presentation/profile_view.dart';
import '../../workout/controllers/analytics_controller.dart';
import '../../workout/controllers/exercise_controller.dart';
import '../../workout/controllers/live_session_controller.dart';
import '../../workout/controllers/workout_history_controller.dart';
import '../../workout/models/analytics_model.dart';
import '../../workout/models/workout_session_model.dart';
import '../../workout/presentation/live_session_page.dart';
import '../../workout/presentation/log_past_session_page.dart';
import '../../workout/presentation/widgets/analytics_view.dart';
import '../../workout/presentation/widgets/exercises_library_view.dart';
import '../../workout/presentation/widgets/session_mode_picker_sheet.dart';
import '../../workout/presentation/widgets/workout_history_view.dart';
import '../../workout/presentation/workout_session_detail_page.dart';
import '../../../../core/services/notification_manager.dart';

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

  // ── 1. Hero Header ──────────────────────────────────────────────────────────
  Widget _buildHeroHeader(UserProfileModel? profile, String fallbackEmail) {
    final name = profile?.name.isNotEmpty == true ? profile!.name : fallbackEmail;
    final initials = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'F';
    final goalText = profile?.fitnessGoal != null ? fitnessGoalLabel(profile!.fitnessGoal) : 'General Fitness';
    final levelText = profile?.experienceLevel != null ? experienceLevelLabel(profile!.experienceLevel) : 'Athlete';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.cardBg,
            AppTheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppTheme.primary, Color(0xFF00F0FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.background,
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreeting(),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '$goalText • $levelText',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  // ── 2. Quick Stats Row ──────────────────────────────────────────────────────
  Widget _buildQuickStatsRow(WorkoutHistoryState historyState, AnalyticsState analyticsState) {
    int totalSessions = historyState.sessions.length;
    if (analyticsState.overview != null && analyticsState.overview!.totalWorkouts > totalSessions) {
      totalSessions = analyticsState.overview!.totalWorkouts;
    }

    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day - now.weekday + 1);
    int workoutsThisWeek = 0;
    double totalVolume = 0;

    for (var session in historyState.sessions) {
      if (session.startDateTime.isAfter(startOfWeek)) {
        workoutsThisWeek++;
      }
      for (var set in session.sets) {
        totalVolume += set.weightKg * set.reps;
      }
    }

    if (analyticsState.overview != null && analyticsState.overview!.totalVolume > totalVolume) {
      totalVolume = analyticsState.overview!.totalVolume;
    }

    String formattedVolume = '${totalVolume.toInt()} kg';
    if (totalVolume >= 100000) {
      formattedVolume = '${(totalVolume / 1000).toStringAsFixed(0)}k kg';
    } else if (totalVolume >= 1000) {
      formattedVolume = '${(totalVolume / 1000).toStringAsFixed(1)}k kg';
    }

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.fitness_center_rounded,
            label: 'Total Volume',
            value: formattedVolume,
            color: const Color(0xFF00F0FF),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.calendar_today_rounded,
            label: 'This Week',
            value: '$workoutsThisWeek sessions',
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.emoji_events_rounded,
            label: 'All-Time',
            value: '$totalSessions workouts',
            color: const Color(0xFFFF007A),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── 3. Weekly Streak Strip ──────────────────────────────────────────────────
  Widget _buildWeeklyStreakStrip(List<WorkoutSessionModel> sessions) {
    final now = DateTime.now();
    // Find Monday of this week
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    int streak = _calculateCurrentStreak(sessions);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFFB800), size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Weekly Activity',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB800).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$streak Day Streak 🔥',
                  style: const TextStyle(
                    color: Color(0xFFFFB800),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final dayDate = monday.add(Duration(days: index));
              final isToday = dayDate.year == now.year && dayDate.month == now.month && dayDate.day == now.day;
              
              // Check if session exists on this day
              final hasWorkout = sessions.any((s) =>
                  s.startDateTime.year == dayDate.year &&
                  s.startDateTime.month == dayDate.month &&
                  s.startDateTime.day == dayDate.day);

              return Column(
                children: [
                  Text(
                    days[index],
                    style: TextStyle(
                      color: isToday ? AppTheme.textPrimary : AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasWorkout
                          ? AppTheme.primary
                          : (isToday ? AppTheme.primary.withValues(alpha: 0.12) : AppTheme.surface),
                      border: Border.all(
                        color: hasWorkout
                            ? AppTheme.primary
                            : (isToday ? AppTheme.primary : Colors.white.withValues(alpha: 0.05)),
                        width: isToday && !hasWorkout ? 1.5 : 1.0,
                      ),
                      boxShadow: hasWorkout
                          ? [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.35),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                    child: Center(
                      child: hasWorkout
                          ? const Icon(Icons.check_rounded, color: Colors.black, size: 20)
                          : (isToday
                              ? Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : null),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  int _calculateCurrentStreak(List<WorkoutSessionModel> sessions) {
    if (sessions.isEmpty) return 0;
    final activeDates = sessions.map((s) => DateTime(s.startDateTime.year, s.startDateTime.month, s.startDateTime.day)).toSet();
    
    final now = DateTime.now();
    var checkDate = DateTime(now.year, now.month, now.day);
    int streak = 0;

    // If today has workout, start counting from today; otherwise if yesterday has workout, count from yesterday
    if (!activeDates.contains(checkDate)) {
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    while (activeDates.contains(checkDate)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    return streak;
  }

  // ── 4. Volume Trend Mini-Chart ──────────────────────────────────────────────
  Widget _buildVolumeTrendCard(AnalyticsOverview? overview, bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.show_chart_rounded, color: Color(0xFF00F0FF), size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Volume Trend (30D)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              if (overview?.volumeHistory.isNotEmpty == true)
                Text(
                  '${overview!.volumeHistory.last.volume.toInt()} kg',
                  style: const TextStyle(
                    color: Color(0xFF00F0FF),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            width: double.infinity,
            child: isLoading
                ? const ForgeSkeleton(height: 120, width: double.infinity)
                : (overview != null && overview.volumeHistory.length >= 2
                    ? CustomPaint(
                        painter: _MiniVolumeChartPainter(
                          points: overview.volumeHistory,
                          lineColor: const Color(0xFF00F0FF),
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.timeline_rounded,
                                color: AppTheme.textSecondary.withValues(alpha: 0.4), size: 36),
                            const SizedBox(height: 8),
                            const Text(
                              'Log more sessions to see trend',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      )),
          ),
        ],
      ),
    );
  }

  // ── 5. Recent Workouts Carousel ─────────────────────────────────────────────
  Widget _buildRecentWorkoutsSection(List<WorkoutSessionModel> sessions, bool isLoading) {
    final recent = sessions.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Workouts',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (sessions.isNotEmpty)
              TextButton(
                onPressed: () => setState(() => _currentIndex = 1),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                child: const Row(
                  children: [
                    Text('View All', style: TextStyle(fontWeight: FontWeight.w600)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 16),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (isLoading)
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, __) => const ForgeSkeleton(width: 260, height: 160),
            ),
          )
        else if (recent.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              children: [
                Icon(Icons.fitness_center_rounded, size: 44, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                const SizedBox(height: 14),
                const Text(
                  'No workouts recorded yet',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Hit the gym or log a past session to track progress.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: recent.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final session = recent[index];
                final imagePath = _getMuscleImageForSession(session);
                double totalVolume = 0;
                for (var s in session.sets) {
                  totalVolume += s.weightKg * s.reps;
                }

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WorkoutSessionDetailPage(sessionId: session.id),
                      ),
                    );
                  },
                  child: Container(
                    width: 260,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: AppTheme.surface,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Image.asset(
                              imagePath,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Image.asset(
                                'assets/images/gym_silhouette.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF0E0E12).withValues(alpha: 0.95),
                                    const Color(0xFF0E0E12).withValues(alpha: 0.70),
                                    const Color(0xFF00F0FF).withValues(alpha: 0.15),
                                  ],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topRight,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _formatDate(session.startDateTime),
                                        style: const TextStyle(
                                          color: AppTheme.primary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${session.durationMinutes ?? 0}m',
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      session.title,
                                      style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          '${session.sets.length} sets',
                                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                        ),
                                        const Text(' • ', style: TextStyle(color: AppTheme.textSecondary)),
                                        Text(
                                          '${totalVolume.toInt()} kg vol',
                                          style: const TextStyle(
                                            color: Color(0xFF00F0FF),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  String _getMuscleImageForSession(WorkoutSessionModel session) {
    if (session.sets.isEmpty) return 'assets/images/gym_silhouette.png';
    final name = session.sets.first.exerciseName.toLowerCase();
    return _getMuscleImagePath(name);
  }

  String _getMuscleImagePath(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('chest') || lower.contains('bench') || lower.contains('fly') || lower.contains('push')) {
      return 'assets/images/muscles/chest.png';
    } else if (lower.contains('back') || lower.contains('row') || lower.contains('lat') || lower.contains('pull')) {
      return 'assets/images/muscles/back.png';
    } else if (lower.contains('leg') || lower.contains('squat') || lower.contains('curl') || lower.contains('press') || lower.contains('calf')) {
      return 'assets/images/muscles/legs.png';
    } else if (lower.contains('shoulder') || lower.contains('delt') || lower.contains('raise')) {
      return 'assets/images/muscles/shoulders.png';
    } else if (lower.contains('arm') || lower.contains('bicep') || lower.contains('tricep') || lower.contains('extension')) {
      return 'assets/images/muscles/arms.png';
    } else if (lower.contains('core') || lower.contains('ab') || lower.contains('plank') || lower.contains('crunch')) {
      return 'assets/images/muscles/core.png';
    } else if (lower.contains('cardio') || lower.contains('run') || lower.contains('bike') || lower.contains('treadmill')) {
      return 'assets/images/muscles/cardio.png';
    }
    return 'assets/images/gym_silhouette.png';
  }

  // ── 6. Muscle Split Donut Chart ─────────────────────────────────────────────
  Widget _buildMuscleSplitCard(AnalyticsOverview? overview, bool isLoading) {
    final dist = overview?.muscleDistribution ?? {};

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart_outline_rounded, color: Color(0xFFFF007A), size: 22),
              const SizedBox(width: 8),
              Text(
                'Muscle Distribution',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (isLoading)
            const ForgeSkeleton(height: 150, width: double.infinity)
          else if (dist.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Icon(Icons.pie_chart_rounded, color: AppTheme.textSecondary.withValues(alpha: 0.3), size: 40),
                    const SizedBox(height: 8),
                    const Text(
                      'No muscle split data yet',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            Row(
              children: [
                SizedBox(
                  width: 130,
                  height: 130,
                  child: CustomPaint(
                    painter: _DonutChartPainter(
                      data: dist,
                      colors: _curatedColors(),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${dist.values.fold(0, (a, b) => a + b)}',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Total Sets',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: dist.entries.take(5).map((e) {
                      final total = dist.values.fold(0, (a, b) => a + b);
                      final percent = total > 0 ? (e.value / total * 100).round() : 0;
                      final color = _curatedColors()[dist.keys.toList().indexOf(e.key) % _curatedColors().length];

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                e.key,
                                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '$percent%',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  List<Color> _curatedColors() => const [
        AppTheme.primary,
        Color(0xFF00F0FF),
        Color(0xFFFF007A),
        Color(0xFF7000FF),
        Color(0xFFFFB800),
        Color(0xFF00FF66),
      ];

  // ── 7. Quick Actions Grid ───────────────────────────────────────────────────
  Widget _buildQuickActionsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionTile(
                title: 'Live Workout',
                subtitle: 'Start tracking now',
                icon: Icons.bolt_rounded,
                color: AppTheme.primary,
                onTap: () async {
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
                    }
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionTile(
                title: 'Log Past Session',
                subtitle: 'Record completed',
                icon: Icons.history_rounded,
                color: const Color(0xFF00F0FF),
                onTap: () async {
                  ref.read(liveSessionControllerProvider.notifier).startPastSession();
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
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionTile(
                title: 'View Analytics',
                subtitle: 'Deep dive metrics',
                icon: Icons.analytics_rounded,
                color: const Color(0xFFFF007A),
                onTap: () => setState(() => _currentIndex = 2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionTile(
                title: 'Exercises',
                subtitle: 'Explore library',
                icon: Icons.fitness_center_rounded,
                color: const Color(0xFF7000FF),
                onTap: () => setState(() => _currentIndex = 3),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppTheme.cardBg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.25)),
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.08),
                Colors.transparent,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  // ── Main Dashboard Tab Build ────────────────────────────────────────────────
  Widget _buildDashboardTab() {
    final historyState = ref.watch(workoutHistoryControllerProvider);
    final analyticsState = ref.watch(analyticsControllerProvider);
    final profileState = ref.watch(profileControllerProvider);
    final userEmail = ref.read(authControllerProvider).value?.split('.').last ?? 'Athlete';

    final isLoading = historyState.isLoadingFirst || profileState.isLoading;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroHeader(profileState.profile, userEmail),
          const SizedBox(height: 20),
          _buildQuickStatsRow(historyState, analyticsState),
          const SizedBox(height: 20),
          _buildWeeklyStreakStrip(historyState.sessions),
          const SizedBox(height: 20),
          _buildVolumeTrendCard(analyticsState.overview, analyticsState.overviewStatus == AnalyticsStatus.loading),
          const SizedBox(height: 24),
          _buildRecentWorkoutsSection(historyState.sessions, historyState.isLoadingFirst),
          const SizedBox(height: 24),
          _buildMuscleSplitCard(analyticsState.overview, analyticsState.overviewStatus == AnalyticsStatus.loading),
          const SizedBox(height: 24),
          _buildQuickActionsGrid(),
          const SizedBox(height: 40),
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
    return '${date.day}/${date.month}';
  }

  Widget _buildWorkoutsTab(bool isActive) {
    return WorkoutHistoryView(isActive: isActive);
  }

  Widget _buildExercisesTab(bool isActive) {
    return ExercisesLibraryView(isActive: isActive);
  }

  Widget _buildProfileTab(bool isActive) {
    return ProfileView(isActive: isActive);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _buildDashboardTab(),
      _buildWorkoutsTab(_currentIndex == 1),
      AnalyticsView(isActive: _currentIndex == 2),
      _buildExercisesTab(_currentIndex == 3),
      _buildProfileTab(_currentIndex == 4),
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
              heroTag: 'dashboard_fab',
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
          if (index != _currentIndex) {
            if (_currentIndex == 2) {
              ref.read(analyticsControllerProvider.notifier).clearSelection();
            }

            if (index == 0) {
              ref.read(workoutHistoryControllerProvider.notifier).fetchFirstPage();
              ref.read(analyticsControllerProvider.notifier).loadAnalyticsData();
            } else if (index == 1) {
              ref.read(workoutHistoryControllerProvider.notifier).fetchFirstPage();
            } else if (index == 2) {
              ref.read(analyticsControllerProvider.notifier).loadAnalyticsData();
            } else if (index == 3) {
              ref.read(exerciseControllerProvider.notifier).fetchFirstPage();
            } else if (index == 4) {
              ref.read(profileControllerProvider.notifier).fetchProfile();
            }
          }
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

// ── Custom Painters for Mini Charts ───────────────────────────────────────────

class _MiniVolumeChartPainter extends CustomPainter {
  final List<VolumeHistoryPoint> points;
  final Color lineColor;

  _MiniVolumeChartPainter({required this.points, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    double maxVal = points.map((e) => e.volume).reduce(math.max);
    double minVal = points.map((e) => e.volume).reduce(math.min);
    if (maxVal == minVal) {
      maxVal += 10;
      minVal = math.max(0, minVal - 10);
    }

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < points.length; i++) {
      final x = (i / (points.length - 1)) * size.width;
      final normalizedY = (points[i].volume - minVal) / (maxVal - minVal);
      final y = size.height - (normalizedY * (size.height * 0.85)) - 6;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          lineColor.withValues(alpha: 0.35),
          lineColor.withValues(alpha: 0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _MiniVolumeChartPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.lineColor != lineColor;
}

class _DonutChartPainter extends CustomPainter {
  final Map<String, int> data;
  final List<Color> colors;

  _DonutChartPainter({required this.data, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final total = data.values.fold(0, (a, b) => a + b);
    if (total == 0) return;

    final rect = Rect.fromLTWH(8, 8, size.width - 16, size.height - 16);
    double startAngle = -math.pi / 2;

    int i = 0;
    for (var entry in data.entries) {
      final sweepAngle = (entry.value / total) * 2 * math.pi;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, startAngle, sweepAngle - 0.08, false, paint);
      startAngle += sweepAngle;
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) =>
      oldDelegate.data != data;
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
