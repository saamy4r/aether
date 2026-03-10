import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';

class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.data,
    this.color = AetherColors.accent,
    this.lineWidth = 1.5,
    this.fillOpacity = 0.15,
  });

  final List<double> data;
  final Color color;
  final double lineWidth;
  final double fillOpacity;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SparklinePainter(
        data: data,
        color: color,
        lineWidth: lineWidth,
        fillOpacity: fillOpacity,
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({
    required this.data,
    required this.color,
    required this.lineWidth,
    required this.fillOpacity,
  });

  final List<double> data;
  final Color color;
  final double lineWidth;
  final double fillOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final max = data.reduce((a, b) => a > b ? a : b);
    final min = data.reduce((a, b) => a < b ? a : b);
    final range = (max - min).clamp(1.0, double.infinity);

    double x(int i) => i / (data.length - 1) * size.width;
    double y(double v) => size.height - ((v - min) / range) * size.height;

    final path = Path()..moveTo(x(0), y(data[0]));
    for (int i = 1; i < data.length; i++) {
      path.lineTo(x(i), y(data[i]));
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..color = color.withOpacity(fillOpacity)
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = lineWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.data != data || old.color != color;
}
