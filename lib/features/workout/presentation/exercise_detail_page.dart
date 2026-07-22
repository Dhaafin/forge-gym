import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/forge_skeleton.dart';
import '../../controllers/exercise_history_controller.dart';
import '../../models/exercise_history_model.dart';
import '../../models/exercise_model.dart';

class ExerciseDetailPage extends ConsumerStatefulWidget {
  final ExerciseModel exercise;

  const ExerciseDetailPage({super.key, required this.exercise});

  @override
  ConsumerState<ExerciseDetailPage> createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends ConsumerState<ExerciseDetailPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 250) {
      ref
          .read(exerciseHistoryControllerProvider(widget.exercise.id).notifier)
          .fetchNextPage();
    }
  }

  String _muscleBgPath(String muscle) {
    final m = muscle.toLowerCase();
    if (m.contains('chest')) return 'assets/images/muscles/chest.png';
    if (m.contains('back')) return 'assets/images/muscles/back.png';
    if (m.contains('leg')) return 'assets/images/muscles/legs.png';
    if (m.contains('shoulder')) return 'assets/images/muscles/shoulders.png';
    if (m.contains('arm')) return 'assets/images/muscles/arms.png';
    if (m.contains('core') || m.contains('abs')) {
      return 'assets/images/muscles/core.png';
    }
    if (m.contains('cardio')) return 'assets/images/muscles/cardio.png';
    return 'assets/images/gym_silhouette.png';
  }

  @override
  Widget build(BuildContext context) {
    final state =
        ref.watch(exerciseHistoryControllerProvider(widget.exercise.id));
    final isLoading = state.status == ExerciseHistoryStatus.loading;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // ── Hero App Bar ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppTheme.surface,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.exercise.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.exercise.targetMuscle.toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    _muscleBgPath(widget.exercise.targetMuscle),
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.05),
                          Colors.black.withValues(alpha: 0.80),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Body ──────────────────────────────────────────────────────────
          if (isLoading)
            const SliverFillRemaining(child: _HistoryLoadingSkeleton())
          else if (state.status == ExerciseHistoryStatus.error)
            SliverFillRemaining(child: _ErrorView(message: state.error ?? 'An error occurred.'))
          else if (state.data == null)
            const SliverFillRemaining(child: _EmptyState())
          else
            _HistoryBody(state: state, exercise: widget.exercise),
        ],
      ),
    );
  }
}

// ── History Body ──────────────────────────────────────────────────────────────

class _HistoryBody extends StatelessWidget {
  final ExerciseHistoryState state;
  final ExerciseModel exercise;

  const _HistoryBody({required this.state, required this.exercise});

  @override
  Widget build(BuildContext context) {
    final data = state.data!;
    final isLoadingMore = state.status == ExerciseHistoryStatus.loadingMore;

    return SliverList(
      delegate: SliverChildListDelegate([
        // ── All-time Stats ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _SectionLabel('All-Time Records'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.fitness_center_rounded,
                  label: 'Max Weight',
                  value: '${data.allTimeMaxWeight.toStringAsFixed(1)} kg',
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  icon: Icons.bolt_rounded,
                  label: 'Est. 1RM',
                  value: '${data.estimated1rm.toStringAsFixed(1)} kg',
                  color: const Color(0xFF00E5FF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  icon: Icons.stacked_bar_chart_rounded,
                  label: 'Max Volume',
                  value: '${(data.allTimeMaxVolume / 1000).toStringAsFixed(1)}K kg',
                  color: const Color(0xFFB39DDB),
                ),
              ),
            ],
          ),
        ),

        // ── Mini Chart ──────────────────────────────────────────────────
        if (data.history.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _SectionLabel('Strength Trend (Est. 1RM)'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: CustomPaint(
                painter: _MiniLinePainter(
                  sessions: data.history,
                  color: const Color(0xFF00E5FF),
                ),
                size: Size.infinite,
              ),
            ),
          ),
        ],

        // ── Session Timeline ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: _SectionLabel('Session History'),
        ),

        if (state.sessions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'No history found for this exercise.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          )
        else
          ...state.sessions.map(
            (session) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: _SessionCard(session: session),
            ),
          ),

        // ── Loading More Indicator ───────────────────────────────────────
        if (isLoadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: CircularProgressIndicator(
                color: AppTheme.primary,
                strokeWidth: 2,
              ),
            ),
          )
        else if (!state.hasMore && state.sessions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                '— ${state.sessions.length} sessions total —',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ),

        const SizedBox(height: 32),
      ]),
    );
  }
}

// ── Session Card ──────────────────────────────────────────────────────────────

class _SessionCard extends StatefulWidget {
  final ExerciseHistorySession session;
  const _SessionCard({required this.session});

  @override
  State<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<_SessionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final dateStr = DateFormat('dd MMM yyyy').format(session.date.toLocal());
    final hasPr = session.sets.any((s) => s.isPr);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasPr
              ? AppTheme.primary.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        children: [
          // Header row
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.calendar_today_rounded,
                        color: AppTheme.primary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                session.sessionTitle,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasPr)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '🏆 PR',
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${session.sessionMaxWeight.toStringAsFixed(1)} kg',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${session.sets.length} sets',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Expanded sets table
          if (_expanded) ...[
            Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.05),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                children: [
                  // Column headers
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: const [
                        SizedBox(
                          width: 30,
                          child: Text('Set',
                              style: TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 11)),
                        ),
                        Expanded(
                          child: Text('Weight',
                              style: TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 11)),
                        ),
                        Expanded(
                          child: Text('Reps',
                              style: TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 11)),
                        ),
                        Expanded(
                          child: Text('Type',
                              style: TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 11)),
                        ),
                        SizedBox(width: 30),
                      ],
                    ),
                  ),
                  ...session.sets.map((set) => _SetRow(set: set)),
                  // Session volume summary
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Session volume',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          '${session.sessionVolume.toStringAsFixed(0)} kg',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Set Row ───────────────────────────────────────────────────────────────────

class _SetRow extends StatelessWidget {
  final ExerciseHistorySet set;
  const _SetRow({required this.set});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '${set.setNumber}',
              style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              '${set.weightKg.toStringAsFixed(1)} kg',
              style: TextStyle(
                color: set.isPr ? AppTheme.primary : AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: set.isPr ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${set.reps} reps',
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                set.setType,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 10),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          SizedBox(
            width: 30,
            child: set.isPr
                ? const Text('🏆',
                    style: TextStyle(fontSize: 13),
                    textAlign: TextAlign.end)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ── Mini Line Chart Painter ───────────────────────────────────────────────────

class _MiniLinePainter extends CustomPainter {
  final List<ExerciseHistorySession> sessions;
  final Color color;

  const _MiniLinePainter({required this.sessions, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (sessions.length < 2) return;

    // Reversed so oldest→newest left→right
    final reversed = sessions.reversed.toList();
    final values = reversed.map((s) => s.sessionEstimated1rm).toList();
    final minVal = values.reduce(math.min);
    final maxVal = values.reduce(math.max);
    final range = (maxVal - minVal).clamp(1.0, double.infinity);

    final points = <Offset>[];
    for (int i = 0; i < reversed.length; i++) {
      final x = i / (reversed.length - 1) * size.width;
      final y =
          size.height - ((values[i] - minVal) / range) * (size.height * 0.8) -
              size.height * 0.1;
      points.add(Offset(x, y));
    }

    // Gradient fill under the curve
    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          colors: [color.withValues(alpha: 0.25), Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Line
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(linePath, linePaint);

    // Dots
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final dotBorderPaint = Paint()
      ..color = AppTheme.surface
      ..style = PaintingStyle.fill;

    for (final p in points) {
      canvas.drawCircle(p, 4, dotBorderPaint);
      canvas.drawCircle(p, 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniLinePainter old) =>
      old.sessions != sessions;
}

// ── Supporting Widgets ────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryLoadingSkeleton extends StatelessWidget {
  const _HistoryLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: ForgeSkeleton(
                      height: 80, borderRadius: BorderRadius.circular(12))),
              const SizedBox(width: 10),
              Expanded(
                  child: ForgeSkeleton(
                      height: 80, borderRadius: BorderRadius.circular(12))),
              const SizedBox(width: 10),
              Expanded(
                  child: ForgeSkeleton(
                      height: 80, borderRadius: BorderRadius.circular(12))),
            ],
          ),
          const SizedBox(height: 16),
          ForgeSkeleton(height: 140, borderRadius: BorderRadius.circular(14)),
          const SizedBox(height: 16),
          ...List.generate(
            4,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ForgeSkeleton(
                  height: 70, borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppTheme.error, size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_rounded, color: AppTheme.textSecondary, size: 48),
          SizedBox(height: 12),
          Text(
            'No history yet.\nStart training to see your progress here!',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
