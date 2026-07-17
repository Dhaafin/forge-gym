import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../controllers/analytics_controller.dart';

class AnalyticsView extends ConsumerWidget {
  final bool isActive;
  const AnalyticsView({super.key, required this.isActive});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isActive) return const SizedBox.shrink();

    final state = ref.watch(analyticsControllerProvider);

    if (state.status == AnalyticsStatus.loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    if (state.status == AnalyticsStatus.error) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 48),
            const SizedBox(height: 16),
            Text(
              state.errorMessage ?? 'Gagal memuat analitik',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(analyticsControllerProvider.notifier).loadAnalyticsData(),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.black),
              child: const Text('COBA LAGI'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(analyticsControllerProvider.notifier).loadAnalyticsData(),
      color: AppTheme.primary,
      backgroundColor: AppTheme.surface,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Period Selector
            _buildPeriodSelector(ref, state.period),
            const SizedBox(height: 20),

            // Summary Stats Grid
            _buildStatsGrid(state),
            const SizedBox(height: 24),

            // Volume Trend Card (Line Chart)
            _buildChartCard(
              title: 'Tren Volume Angkatan (kg)',
              subtitle: 'Total volume beban dikali repetisi',
              icon: Icons.show_chart_rounded,
              child: SizedBox(
                height: 200,
                child: CustomPaint(
                  painter: _LineChartPainter(points: state.volumePoints),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Workout Frequency Card (Bar Chart)
            _buildChartCard(
              title: 'Frekuensi Latihan (Sesi)',
              subtitle: 'Jumlah sesi latihan yang diselesaikan',
              icon: Icons.bar_chart_rounded,
              child: SizedBox(
                height: 200,
                child: CustomPaint(
                  painter: _BarChartPainter(points: state.frequencyPoints),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Muscle Group Shares (Doughnut Chart)
            _buildChartCard(
              title: 'Distribusi Volume Otot',
              subtitle: 'Persentase set latihan berdasarkan target otot',
              icon: Icons.pie_chart_rounded,
              child: state.muscleGroupShares.isEmpty
                  ? const SizedBox(
                      height: 160,
                      child: Center(
                        child: Text(
                          'Belum ada data set latihan.',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      ),
                    )
                  : _buildMuscleDistributionSection(state.muscleGroupShares),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(WidgetRef ref, AnalyticsPeriod current) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: AnalyticsPeriod.values.map((p) {
          final isSelected = p == current;
          String label = '';
          switch (p) {
            case AnalyticsPeriod.week:
              label = 'Minggu';
              break;
            case AnalyticsPeriod.month:
              label = 'Bulan';
              break;
            case AnalyticsPeriod.year:
              label = 'Tahun';
              break;
          }

          return Expanded(
            child: GestureDetector(
              onTap: () => ref.read(analyticsControllerProvider.notifier).setPeriod(p),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white60,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatsGrid(AnalyticsState state) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: [
        _buildStatCard(
          'Total Volume',
          '${state.totalVolume >= 1000 ? (state.totalVolume / 1000).toStringAsFixed(1) : state.totalVolume.toInt()} ${state.totalVolume >= 1000 ? 't' : 'kg'}',
          Icons.fitness_center_rounded,
          AppTheme.primary,
        ),
        _buildStatCard(
          'Total Sesi',
          '${state.workoutCount}',
          Icons.calendar_today_rounded,
          Colors.blueAccent,
        ),
        _buildStatCard(
          'Rata-rata Durasi',
          '${state.avgDuration.toInt()} m',
          Icons.timer_rounded,
          Colors.purpleAccent,
        ),
        _buildStatCard(
          'Rekor Baru (PR)',
          '${state.prsCount}',
          Icons.emoji_events_rounded,
          Colors.orangeAccent,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Icon(icon, color: color.withValues(alpha: 0.8), size: 18),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
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
            children: [
              Icon(icon, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildMuscleDistributionSection(Map<String, double> shares) {
    // Sort shares descending
    final sortedList = shares.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Limit to top 5, rest as 'Other'
    final topList = sortedList.take(5).toList();
    double otherSum = 0.0;
    if (sortedList.length > 5) {
      for (int i = 5; i < sortedList.length; i++) {
        otherSum += sortedList[i].value;
      }
      topList.add(MapEntry('Other', otherSum));
    }

    final chartColors = [
      AppTheme.primary,
      Colors.blueAccent,
      Colors.purpleAccent,
      Colors.orangeAccent,
      Colors.pinkAccent,
      Colors.tealAccent,
    ];

    final Map<String, Color> shareColors = {};
    for (int i = 0; i < topList.length; i++) {
      shareColors[topList[i].key] = chartColors[i % chartColors.length];
    }

    return Row(
      children: [
        // Doughnut Chart Painter
        Expanded(
          flex: 4,
          child: AspectRatio(
            aspectRatio: 1.0,
            child: CustomPaint(
              painter: _DoughnutChartPainter(
                shares: topList,
                colors: shareColors,
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        // Legend
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: topList.map((entry) {
              final color = shareColors[entry.key] ?? Colors.grey;
              final percent = (entry.value * 100).toInt();

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '$percent%',
                      style: const TextStyle(color: Colors.white30, fontSize: 12, fontWeight: FontWeight.bold),
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

// -------------------------------------------------------------
// Custom Painters for charts
// -------------------------------------------------------------

class _LineChartPainter extends CustomPainter {
  final List<ProgressPoint> points;
  _LineChartPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final double paddingLeft = 35.0;
    final double paddingRight = 10.0;
    final double paddingTop = 10.0;
    final double paddingBottom = 25.0;

    final double width = size.width - paddingLeft - paddingRight;
    final double height = size.height - paddingTop - paddingBottom;

    // Find min and max Y
    double maxY = points.map((p) => p.value).reduce(math.max);
    double minY = 0.0; // always baseline at 0 for weight volume
    if (maxY == 0.0) maxY = 1.0;

    // Draw horizontal grid lines
    final Paint gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    final int gridLines = 4;
    for (int i = 0; i <= gridLines; i++) {
      final double y = paddingTop + height - (i * height / gridLines);
      canvas.drawLine(
        Offset(paddingLeft, y),
        Offset(paddingLeft + width, y),
        gridPaint,
      );

      // Y Axis Label
      final double gridVal = minY + (i * (maxY - minY) / gridLines);
      String yLabel;
      if (gridVal >= 1000) {
        yLabel = '${(gridVal / 1000).toStringAsFixed(1)}k';
      } else {
        yLabel = '${gridVal.toInt()}';
      }

      _drawText(
        canvas,
        Offset(paddingLeft - 8, y - 7),
        yLabel,
        Colors.white30,
        10,
        Alignment.centerRight,
      );
    }

    // Map points to canvas coordinates
    final List<Offset> offsetPoints = [];
    final double dx = points.length > 1 ? width / (points.length - 1) : width;

    for (int i = 0; i < points.length; i++) {
      final double px = paddingLeft + (i * dx);
      final double py = paddingTop + height - ((points[i].value - minY) / (maxY - minY) * height);
      offsetPoints.add(Offset(px, py));

      // X Axis Label
      _drawText(
        canvas,
        Offset(px, paddingTop + height + 8),
        points[i].label,
        Colors.white30,
        10,
        Alignment.topCenter,
      );
    }

    // Draw area fill under the line
    if (offsetPoints.length > 1) {
      final Path fillPath = Path()
        ..moveTo(offsetPoints.first.dx, paddingTop + height);

      for (var point in offsetPoints) {
        fillPath.lineTo(point.dx, point.dy);
      }
      fillPath.lineTo(offsetPoints.last.dx, paddingTop + height);
      fillPath.close();

      final Paint fillPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.25),
            AppTheme.primary.withValues(alpha: 0.0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTRB(paddingLeft, paddingTop, paddingLeft + width, paddingTop + height));

      canvas.drawPath(fillPath, fillPaint);
    }

    // Draw neon curve path
    final Paint linePaint = Paint()
      ..color = AppTheme.primary
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Glowing effect
    final Paint shadowPaint = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.4)
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..imageFilter = ImageFilter.blur(sigmaX: 3, sigmaY: 3);

    if (offsetPoints.length > 1) {
      final Path linePath = Path()..moveTo(offsetPoints.first.dx, offsetPoints.first.dy);
      for (int i = 1; i < offsetPoints.length; i++) {
        // smooth bezier curves
        final prev = offsetPoints[i - 1];
        final curr = offsetPoints[i];
        final controlX1 = prev.dx + (curr.dx - prev.dx) / 2;
        final controlY1 = prev.dy;
        final controlX2 = prev.dx + (curr.dx - prev.dx) / 2;
        final controlY2 = curr.dy;

        linePath.cubicTo(controlX1, controlY1, controlX2, controlY2, curr.dx, curr.dy);
      }

      canvas.drawPath(linePath, shadowPaint);
      canvas.drawPath(linePath, linePaint);
    }

    // Draw point circles
    final Paint outerPointPaint = Paint()..color = AppTheme.primary;
    final Paint innerPointPaint = Paint()..color = Colors.black;

    for (var point in offsetPoints) {
      canvas.drawCircle(point, 5.0, outerPointPaint);
      canvas.drawCircle(point, 2.5, innerPointPaint);
    }
  }

  void _drawText(Canvas canvas, Offset offset, String text, Color color, double size, Alignment align) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    double dx = offset.dx;
    if (align == Alignment.centerRight) {
      dx -= tp.width;
    } else if (align == Alignment.topCenter) {
      dx -= tp.width / 2;
    }

    tp.paint(canvas, Offset(dx, offset.dy));
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => oldDelegate.points != points;
}

class _BarChartPainter extends CustomPainter {
  final List<ProgressPoint> points;
  _BarChartPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final double paddingLeft = 30.0;
    final double paddingRight = 10.0;
    final double paddingTop = 10.0;
    final double paddingBottom = 25.0;

    final double width = size.width - paddingLeft - paddingRight;
    final double height = size.height - paddingTop - paddingBottom;

    // Find max Y
    double maxY = points.map((p) => p.value).reduce(math.max);
    if (maxY == 0.0) maxY = 1.0;

    // Ensure integer levels for frequencies
    if (maxY < 5) maxY = 5;

    // Draw horizontal grid lines
    final Paint gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    // Reduce number of lines if too tall
    final int interval = (maxY / 5).ceil();

    for (int i = 0; i <= maxY; i += interval) {
      final double y = paddingTop + height - (i * height / maxY);
      canvas.drawLine(
        Offset(paddingLeft, y),
        Offset(paddingLeft + width, y),
        gridPaint,
      );

      // Y axis label
      _drawText(
        canvas,
        Offset(paddingLeft - 8, y - 7),
        '$i',
        Colors.white30,
        10,
        Alignment.centerRight,
      );
    }

    final double totalBars = points.length.toDouble();
    final double spacingPercent = 0.35; // Spacing ratio between bars
    final double totalSpacing = width * spacingPercent;
    final double totalBarWidths = width - totalSpacing;
    final double barWidth = totalBarWidths / totalBars;
    final double spacing = totalSpacing / (totalBars + 1);

    final Paint barPaint = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.fill;

    // Glowing border for bar chart
    final Paint glowPaint = Paint()
      ..color = Colors.blueAccent.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill
      ..imageFilter = ImageFilter.blur(sigmaX: 4, sigmaY: 4);

    for (int i = 0; i < points.length; i++) {
      final double barHeight = (points[i].value / maxY) * height;
      if (barHeight == 0.0) {
        // Just draw label
        final double bx = paddingLeft + spacing + (i * (barWidth + spacing)) + (barWidth / 2);
        _drawText(
          canvas,
          Offset(bx, paddingTop + height + 8),
          points[i].label,
          Colors.white30,
          10,
          Alignment.topCenter,
        );
        continue;
      }

      final double bx = paddingLeft + spacing + (i * (barWidth + spacing));
      final double by = paddingTop + height - barHeight;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTRB(bx, by, bx + barWidth, paddingTop + height),
        const Radius.circular(6),
      );

      canvas.drawRRect(rect, glowPaint);
      canvas.drawRRect(rect, barPaint);

      // X Label
      _drawText(
        canvas,
        Offset(bx + (barWidth / 2), paddingTop + height + 8),
        points[i].label,
        Colors.white30,
        10,
        Alignment.topCenter,
      );
    }
  }

  void _drawText(Canvas canvas, Offset offset, String text, Color color, double size, Alignment align) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    double dx = offset.dx;
    if (align == Alignment.centerRight) {
      dx -= tp.width;
    } else if (align == Alignment.topCenter) {
      dx -= tp.width / 2;
    }

    tp.paint(canvas, Offset(dx, offset.dy));
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) => oldDelegate.points != points;
}

class _DoughnutChartPainter extends CustomPainter {
  final List<MapEntry<String, double>> shares;
  final Map<String, Color> colors;

  _DoughnutChartPainter({required this.shares, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = math.min(size.width, size.height) / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);

    final double strokeWidth = radius * 0.35;
    final double chartRadius = radius - (strokeWidth / 2);

    double startAngle = -math.pi / 2;

    final Paint arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    for (final entry in shares) {
      final sweepAngle = entry.value * 2 * math.pi;
      final color = colors[entry.key] ?? Colors.grey;

      arcPaint.color = color;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: chartRadius),
        startAngle,
        sweepAngle,
        false,
        arcPaint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DoughnutChartPainter oldDelegate) {
    return oldDelegate.shares != shares || oldDelegate.colors != colors;
  }
}
