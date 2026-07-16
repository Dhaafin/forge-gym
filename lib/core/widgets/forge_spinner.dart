import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ForgeSpinner extends StatefulWidget {
  final double size;
  final Color? color;
  final double strokeWidth;

  const ForgeSpinner({
    super.key,
    this.size = 24.0,
    this.color,
    this.strokeWidth = 2.5,
  });

  @override
  State<ForgeSpinner> createState() => _ForgeSpinnerState();
}

class _ForgeSpinnerState extends State<ForgeSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spinnerColor = widget.color ?? AppTheme.primary;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _ForgeSpinnerPainter(
            rotationValue: _controller.value,
            color: spinnerColor,
            strokeWidth: widget.strokeWidth,
          ),
        );
      },
    );
  }
}

class _ForgeSpinnerPainter extends CustomPainter {
  final double rotationValue;
  final Color color;
  final double strokeWidth;

  _ForgeSpinnerPainter({
    required this.rotationValue,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = Offset(size.width / 2, size.height / 2);

    // Outer ring paint (spinning clockwise)
    final outerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Inner ring paint (spinning counter-clockwise)
    final innerPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.75
      ..strokeCap = StrokeCap.round;

    final double outerStartAngle = rotationValue * 2 * math.pi;
    final double outerSweepAngle = 1.2 * math.pi; // 216 degrees arc

    final double innerStartAngle = -rotationValue * 2 * math.pi;
    final double innerSweepAngle = 0.8 * math.pi; // 144 degrees arc

    // Draw outer arc
    canvas.drawArc(
      rect,
      outerStartAngle,
      outerSweepAngle,
      false,
      outerPaint,
    );

    // Draw inner arc (slightly smaller radius)
    final innerRadius = (size.width / 2) - strokeWidth - 1.5;
    final innerRect = Rect.fromCircle(
      center: center,
      radius: innerRadius > 0 ? innerRadius : 1.0,
    );
    canvas.drawArc(
      innerRect,
      innerStartAngle,
      innerSweepAngle,
      false,
      innerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ForgeSpinnerPainter oldDelegate) {
    return oldDelegate.rotationValue != rotationValue ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
