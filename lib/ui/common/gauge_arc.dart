import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';

class GaugeArc extends StatelessWidget {
  const GaugeArc({
    super.key,
    required this.value,
    required this.label,
    this.unit = '%',
    this.color = AetherColors.accent,
    this.trackColor = AetherColors.glassBase,
    this.size = 80,
    this.strokeWidth = 8,
  });

  final double value; // 0–100
  final String label;
  final String unit;
  final Color color;
  final Color trackColor;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _GaugePainter(
              value: value.clamp(0, 100),
              color: color,
              trackColor: trackColor,
              strokeWidth: strokeWidth,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${value.round()}$unit',
                style: TextStyle(
                  color: AetherColors.textPrimary,
                  fontSize: size * 0.18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: AetherColors.textSecondary,
                  fontSize: size * 0.12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({
    required this.value,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double value;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    const startAngle = pi * 0.75;
    const sweepTotal = pi * 1.5;
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, sweepTotal, false, trackPaint);
    canvas.drawArc(rect, startAngle, sweepTotal * (value / 100), false, valuePaint);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.value != value;
}
