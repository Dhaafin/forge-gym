import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/forge_skeleton.dart';
import '../../../../core/widgets/forge_api_bottom_sheet.dart';
import '../../controllers/analytics_controller.dart';
import '../../models/analytics_model.dart';
import '../../models/exercise_model.dart';
import '../../services/workout_service.dart';

class AnalyticsView extends ConsumerWidget {
  final bool isActive;
  const AnalyticsView({super.key, required this.isActive});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isActive) return const SizedBox.shrink();

    final state = ref.watch(analyticsControllerProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(analyticsControllerProvider.notifier).loadAnalyticsData(),
      color: AppTheme.primary,
      backgroundColor: AppTheme.surface,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Range Selector ──────────────────────────────────────────────
            _RangeSelector(
              selected: state.selectedRange,
              onChanged: (r) => ref.read(analyticsControllerProvider.notifier).setRange(r),
            ),
            const SizedBox(height: 20),

            // ── KPI Cards ───────────────────────────────────────────────────
            if (state.overviewStatus == AnalyticsStatus.loading)
              _KpiCardsSkeleton()
            else if (state.overviewStatus == AnalyticsStatus.error)
              _ErrorBanner(
                message: state.overviewError ?? 'Failed to load analytics.',
                onRetry: () => ref.read(analyticsControllerProvider.notifier).loadAnalyticsData(),
              )
            else if (state.overview != null)
              _KpiGrid(overview: state.overview!),

            const SizedBox(height: 24),

            // ── Volume Trend Chart ──────────────────────────────────────────
            if (state.overviewStatus == AnalyticsStatus.loading)
              _ChartSkeleton(height: 240)
            else if (state.overview != null)
              _ChartCard(
                title: 'Volume Trend',
                subtitle: 'Daily lifting volume (${state.overview!.unit})',
                icon: Icons.show_chart_rounded,
                child: state.overview!.volumeHistory.isEmpty
                    ? _EmptyChart(message: 'No volume data for this period.')
                    : SizedBox(
                        height: 200,
                        child: CustomPaint(
                          painter: _AreaChartPainter(
                            points: state.overview!.volumeHistory,
                            unit: state.overview!.unit,
                          ),
                          size: Size.infinite,
                        ),
                      ),
              ),

            const SizedBox(height: 20),

            // ── Muscle Distribution Chart ───────────────────────────────────
            if (state.overviewStatus == AnalyticsStatus.loading)
              _ChartSkeleton(height: 200)
            else if (state.overview != null)
              _ChartCard(
                title: 'Muscle Distribution',
                subtitle: 'Total sets per target muscle',
                icon: Icons.pie_chart_rounded,
                child: state.overview!.muscleDistribution.isEmpty
                    ? _EmptyChart(message: 'No muscle data for this period.')
                    : _MuscleDistributionBody(
                        distribution: state.overview!.muscleDistribution,
                      ),
              ),

            const SizedBox(height: 20),

            // ── Exercise Progression Chart ──────────────────────────────────
            _ExerciseProgressionSection(state: state),
          ],
        ),
      ),
    );
  }
}

// ── Range Selector ────────────────────────────────────────────────────────────

class _RangeSelector extends StatelessWidget {
  final AnalyticsRange selected;
  final void Function(AnalyticsRange) onChanged;

  const _RangeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: AnalyticsRange.values.map((range) {
          final isSelected = range == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(range),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Text(
                  range.label,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white54,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── KPI Grid ──────────────────────────────────────────────────────────────────

class _KpiGrid extends StatelessWidget {
  final AnalyticsOverview overview;
  const _KpiGrid({required this.overview});

  String _formatVolume(double vol, String unit) {
    if (vol >= 1000) {
      return '${(vol / 1000).toStringAsFixed(1)}k ${unit}';
    }
    return '${vol.toStringAsFixed(0)} $unit';
  }

  String _formatDuration(int minutes) {
    if (minutes == 0) return '0m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _KpiCard(
            label: 'Total Volume',
            value: _formatVolume(overview.totalVolume, overview.unit),
            icon: Icons.fitness_center_rounded,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _KpiCard(
            label: 'Workouts',
            value: '${overview.totalWorkouts}',
            icon: Icons.calendar_today_rounded,
            color: Colors.blueAccent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _KpiCard(
            label: 'Duration',
            value: _formatDuration(overview.totalDurationMinutes),
            icon: Icons.timer_rounded,
            color: Colors.purpleAccent,
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Icon(icon, color: color.withValues(alpha: 0.8), size: 16),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Chart Card Shell ──────────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final Widget? headerTrailing;

  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.headerTrailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (headerTrailing != null) headerTrailing!,
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

// ── Empty Chart Placeholder ───────────────────────────────────────────────────

class _EmptyChart extends StatelessWidget {
  final String message;
  const _EmptyChart({required this.message});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ── Error Banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.wifi_off_rounded, color: AppTheme.error, size: 36),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style:
                const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primary, size: 18),
            label: const Text('Retry', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }
}

// ── Skeleton helpers ──────────────────────────────────────────────────────────

class _KpiCardsSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        3,
        (i) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < 2 ? 10 : 0),
            child: const ForgeSkeleton(
              height: 80,
              width: double.infinity,
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChartSkeleton extends StatelessWidget {
  final double height;
  const _ChartSkeleton({required this.height});

  @override
  Widget build(BuildContext context) {
    return ForgeSkeleton(
      height: height,
      width: double.infinity,
      borderRadius: const BorderRadius.all(Radius.circular(20)),
    );
  }
}

// ── Muscle Distribution ───────────────────────────────────────────────────────

class _MuscleDistributionBody extends StatelessWidget {
  final Map<String, int> distribution;
  const _MuscleDistributionBody({required this.distribution});

  static const _chartColors = [
    AppTheme.primary,
    Colors.blueAccent,
    Colors.purpleAccent,
    Colors.orangeAccent,
    Colors.pinkAccent,
    Colors.tealAccent,
  ];

  @override
  Widget build(BuildContext context) {
    final total = distribution.values.fold(0, (a, b) => a + b);
    if (total == 0) return _EmptyChart(message: 'No set data for this period.');

    final sorted = distribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top = sorted.take(5).toList();
    if (sorted.length > 5) {
      final otherSum = sorted.skip(5).fold(0, (acc, e) => acc + e.value);
      top.add(MapEntry('Other', otherSum));
    }

    final colors = {
      for (int i = 0; i < top.length; i++)
        top[i].key: _chartColors[i % _chartColors.length]
    };

    // compute shares
    final topTotal = top.fold(0, (acc, e) => acc + e.value);

    return Row(
      children: [
        Expanded(
          flex: 4,
          child: AspectRatio(
            aspectRatio: 1.0,
            child: CustomPaint(
              painter: _DonutPainter(entries: top, colors: colors),
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: top.map((entry) {
              final color = colors[entry.key] ?? Colors.grey;
              final pct = topTotal > 0
                  ? ((entry.value / topTotal) * 100).round()
                  : 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '$pct%',
                      style: const TextStyle(
                          color: Colors.white30,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ── Exercise Progression Section ──────────────────────────────────────────────

class _ExerciseProgressionSection extends ConsumerStatefulWidget {
  final AnalyticsState state;
  const _ExerciseProgressionSection({required this.state});

  @override
  ConsumerState<_ExerciseProgressionSection> createState() =>
      _ExerciseProgressionSectionState();
}

class _ExerciseProgressionSectionState
    extends ConsumerState<_ExerciseProgressionSection> {
  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final ctrl = ref.read(analyticsControllerProvider.notifier);

    return _ChartCard(
      title: 'Exercise Progression',
      subtitle: state.selectedExercise?.name ?? 'Select an exercise',
      icon: Icons.trending_up_rounded,
      headerTrailing: _ProgressionToggle(
        selected: state.progressionMetric,
        onChanged: (m) => ctrl.setProgressionMetric(m),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Exercise Selector Tile
          _buildSelectorField(
            label: 'Select Exercise',
            valueText: state.selectedExercise?.name ?? 'Choose an exercise',
            icon: Icons.search_rounded,
            onTap: () async {
              final selected = await showForgeApiOptionSelector<ExerciseModel>(
                context: context,
                title: 'Select Exercise',
                subtitle: 'Choose an exercise to view progression',
                selectedValue: state.selectedExercise,
                fetchItems: (query, offset) => ref.read(workoutServiceProvider).fetchExercises(
                      search: query,
                      offset: offset,
                      limit: 10,
                    ),
                labelBuilder: (e) => e.name,
                idBuilder: (e) => e.id,
                iconBuilder: (e) => Icons.fitness_center_rounded,
              );
              if (selected != null) {
                ctrl.selectExercise(selected);
              }
            },
          ),
          const SizedBox(height: 16),

          // Records badges
          if (state.progressionStatus == AnalyticsStatus.success &&
              state.progression != null)
            _RecordBadges(
              progression: state.progression!,
              metric: state.progressionMetric,
            ),

          const SizedBox(height: 16),

          // Chart
          if (state.selectedExercise == null)
            const _EmptyChart(
                message: 'Select an exercise to view progression.')
          else if (state.progressionStatus == AnalyticsStatus.loading)
            const ForgeSkeleton(
              height: 200,
              width: double.infinity,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            )
          else if (state.progressionStatus == AnalyticsStatus.error)
            _EmptyChart(
                message: state.progressionError ?? 'Failed to load progression.')
          else if (state.progression == null || state.progression!.history.isEmpty)
            _EmptyChart(
                message: 'No progression data found for this exercise.')
          else
            SizedBox(
              height: 200,
              child: CustomPaint(
                painter: _ProgressionChartPainter(
                  points: state.progression!.history,
                  metric: state.progressionMetric,
                  unit: state.progression!.unit,
                ),
                size: Size.infinite,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectorField({
    required String label,
    required String valueText,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppTheme.textSecondary, size: 20),
          suffixIcon: const Icon(Icons.expand_more_rounded, color: AppTheme.textSecondary),
        ),
        child: Text(
          valueText,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
        ),
      ),
    );
  }
}

class _ProgressionToggle extends StatelessWidget {
  final ProgressionMetric selected;
  final void Function(ProgressionMetric) onChanged;
  const _ProgressionToggle(
      {required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleBtn('Weight', ProgressionMetric.maxWeight),
          const SizedBox(width: 3),
          _toggleBtn('1RM', ProgressionMetric.estimated1rm),
        ],
      ),
    );
  }

  Widget _toggleBtn(String label, ProgressionMetric m) {
    final isSelected = selected == m;
    return GestureDetector(
      onTap: () => onChanged(m),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white54,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}



class _RecordBadges extends StatelessWidget {
  final ExerciseProgression progression;
  final ProgressionMetric metric;
  const _RecordBadges({required this.progression, required this.metric});

  @override
  Widget build(BuildContext context) {
    final isWeight = metric == ProgressionMetric.maxWeight;
    final value = isWeight
        ? '${progression.maxWeight.toStringAsFixed(1)} ${progression.unit}'
        : '${progression.maxEstimated1rm.toStringAsFixed(1)} ${progression.unit}';
    final label = isWeight ? '🏆 All-time Max Weight' : '🏆 All-time Est. 1RM';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.12),
            AppTheme.primary.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12)),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Custom Painters ───────────────────────────────────────────────────────────

class _DonutPainter extends CustomPainter {
  final List<MapEntry<String, int>> entries;
  final Map<String, Color> colors;

  const _DonutPainter({required this.entries, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final total = entries.fold(0, (acc, e) => acc + e.value);
    if (total == 0) return;

    final radius = math.min(size.width, size.height) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = radius * 0.35;
    final chartRadius = radius - strokeWidth / 2;

    double startAngle = -math.pi / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    for (final entry in entries) {
      final sweep = (entry.value / total) * 2 * math.pi;
      paint.color = colors[entry.key] ?? Colors.grey;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: chartRadius),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.entries != entries || old.colors != colors;
}

class _AreaChartPainter extends CustomPainter {
  final List<VolumeHistoryPoint> points;
  final String unit;

  const _AreaChartPainter({required this.points, required this.unit});

  static const double _padL = 45.0;
  static const double _padR = 10.0;
  static const double _padT = 10.0;
  static const double _padB = 28.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final w = size.width - _padL - _padR;
    final h = size.height - _padT - _padB;

    double maxY = points.map((p) => p.volume).reduce(math.max);
    if (maxY == 0) maxY = 1;

    // Grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = _padT + h - (i * h / 4);
      canvas.drawLine(Offset(_padL, y), Offset(_padL + w, y), gridPaint);

      final val = (maxY * i / 4);
      final label = val >= 1000
          ? '${(val / 1000).toStringAsFixed(1)}k'
          : val.toInt().toString();
      _drawText(canvas, Offset(_padL - 6, y - 7), label, Colors.white30, 9,
          Alignment.centerRight);
    }

    // Map to canvas coords
    final dx = points.length > 1 ? w / (points.length - 1) : w;
    final offsets = <Offset>[];
    for (int i = 0; i < points.length; i++) {
      final px = _padL + i * dx;
      final py = _padT + h - (points[i].volume / maxY * h);
      offsets.add(Offset(px, py));
    }

    // X labels — show a subset to avoid overlap
    final step = (points.length / 5).ceil().clamp(1, points.length);
    for (int i = 0; i < points.length; i += step) {
      final dt = points[i].date;
      final label = '${_monthAbbr(dt.month)} ${dt.day}';
      _drawText(
        canvas,
        Offset(offsets[i].dx, _padT + h + 6),
        label,
        Colors.white30,
        9,
        Alignment.topCenter,
      );
    }

    // Area fill
    if (offsets.length > 1) {
      final fillPath = Path()
        ..moveTo(offsets.first.dx, _padT + h);
      for (final o in offsets) {
        fillPath.lineTo(o.dx, o.dy);
      }
      fillPath
        ..lineTo(offsets.last.dx, _padT + h)
        ..close();

      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            colors: [
              AppTheme.primary.withValues(alpha: 0.28),
              AppTheme.primary.withValues(alpha: 0.0),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Rect.fromLTRB(_padL, _padT, _padL + w, _padT + h)),
      );
    }

    // Smooth line
    final linePath = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (int i = 1; i < offsets.length; i++) {
      final prev = offsets[i - 1];
      final curr = offsets[i];
      final cpX = prev.dx + (curr.dx - prev.dx) / 2;
      linePath.cubicTo(cpX, prev.dy, cpX, curr.dy, curr.dx, curr.dy);
    }

    // Glow
    canvas.drawPath(
      linePath,
      Paint()
        ..color = AppTheme.primary.withValues(alpha: 0.4)
        ..strokeWidth = 6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..imageFilter = ImageFilter.blur(sigmaX: 3, sigmaY: 3),
    );
    canvas.drawPath(
      linePath,
      Paint()
        ..color = AppTheme.primary
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Dots
    for (final o in offsets) {
      canvas.drawCircle(o, 4.5, Paint()..color = AppTheme.primary);
      canvas.drawCircle(o, 2.5, Paint()..color = Colors.black);
    }
  }

  String _monthAbbr(int m) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return months[m - 1];
  }

  void _drawText(Canvas canvas, Offset offset, String text, Color color,
      double size, Alignment align) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              color: color,
              fontSize: size,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace')),
      textDirection: TextDirection.ltr,
    )..layout();

    double dx = offset.dx;
    if (align == Alignment.centerRight) dx -= tp.width;
    if (align == Alignment.topCenter) dx -= tp.width / 2;
    tp.paint(canvas, Offset(dx, offset.dy));
  }

  @override
  bool shouldRepaint(covariant _AreaChartPainter old) =>
      old.points != points || old.unit != unit;
}

class _ProgressionChartPainter extends CustomPainter {
  final List<ExerciseProgressionPoint> points;
  final ProgressionMetric metric;
  final String unit;

  const _ProgressionChartPainter({
    required this.points,
    required this.metric,
    required this.unit,
  });

  static const double _padL = 48.0;
  static const double _padR = 10.0;
  static const double _padT = 10.0;
  static const double _padB = 28.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final w = size.width - _padL - _padR;
    final h = size.height - _padT - _padB;

    final values = points
        .map((p) => metric == ProgressionMetric.maxWeight
            ? p.maxWeight
            : p.estimated1rm)
        .toList();

    double minY = values.reduce(math.min);
    double maxY = values.reduce(math.max);
    if (maxY == minY) {
      minY = (minY - 10).clamp(0, double.infinity);
      maxY += 10;
    }

    // Grid
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = _padT + h - (i * h / 4);
      canvas.drawLine(Offset(_padL, y), Offset(_padL + w, y), gridPaint);
      final val = minY + (maxY - minY) * i / 4;
      _drawText(canvas, Offset(_padL - 6, y - 7), '${val.toStringAsFixed(0)}',
          Colors.white30, 9, Alignment.centerRight);
    }

    final dx = points.length > 1 ? w / (points.length - 1) : w;
    final offsets = <Offset>[];
    for (int i = 0; i < points.length; i++) {
      final v = metric == ProgressionMetric.maxWeight
          ? points[i].maxWeight
          : points[i].estimated1rm;
      final px = _padL + i * dx;
      final py = _padT + h - ((v - minY) / (maxY - minY) * h);
      offsets.add(Offset(px, py));
    }

    // X labels
    final step = (points.length / 5).ceil().clamp(1, points.length);
    for (int i = 0; i < points.length; i += step) {
      final dt = points[i].date;
      final label = '${_monthAbbr(dt.month)} ${dt.day}';
      _drawText(canvas, Offset(offsets[i].dx, _padT + h + 6), label,
          Colors.white30, 9, Alignment.topCenter);
    }

    // Line
    final linePath = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (int i = 1; i < offsets.length; i++) {
      final prev = offsets[i - 1];
      final curr = offsets[i];
      final cpX = prev.dx + (curr.dx - prev.dx) / 2;
      linePath.cubicTo(cpX, prev.dy, cpX, curr.dy, curr.dx, curr.dy);
    }

    canvas.drawPath(
      linePath,
      Paint()
        ..color = Colors.purpleAccent.withValues(alpha: 0.4)
        ..strokeWidth = 6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..imageFilter = ImageFilter.blur(sigmaX: 3, sigmaY: 3),
    );
    canvas.drawPath(
      linePath,
      Paint()
        ..color = Colors.purpleAccent
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    for (final o in offsets) {
      canvas.drawCircle(o, 4.5, Paint()..color = Colors.purpleAccent);
      canvas.drawCircle(o, 2.5, Paint()..color = Colors.black);
    }
  }

  String _monthAbbr(int m) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return months[m - 1];
  }

  void _drawText(Canvas canvas, Offset offset, String text, Color color,
      double size, Alignment align) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              color: color,
              fontSize: size,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace')),
      textDirection: TextDirection.ltr,
    )..layout();

    double dx = offset.dx;
    if (align == Alignment.centerRight) dx -= tp.width;
    if (align == Alignment.topCenter) dx -= tp.width / 2;
    tp.paint(canvas, Offset(dx, offset.dy));
  }

  @override
  bool shouldRepaint(covariant _ProgressionChartPainter old) =>
      old.points != points || old.metric != metric || old.unit != unit;
}
