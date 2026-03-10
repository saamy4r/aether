import 'dart:math';
import 'package:flutter/material.dart';

class DesktopWallpaper extends StatelessWidget {
  const DesktopWallpaper({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WallpaperPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _WallpaperPainter extends CustomPainter {
  // Fixed seed so the wallpaper is deterministic across rebuilds
  static final _rng = Random(42);

  static final List<_Star> _stars = List.generate(220, (_) {
    return _Star(
      x: _rng.nextDouble(),
      y: _rng.nextDouble(),
      radius: _rng.nextDouble() * 1.4 + 0.3,
      opacity: _rng.nextDouble() * 0.7 + 0.3,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Base dark gradient ─────────────────────────────────────────────────
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF0A0E1A),
          Color(0xFF0D1525),
          Color(0xFF111C30),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // ── Nebula glow — top-left (blue/violet) ──────────────────────────────
    _drawGlow(
      canvas,
      center: Offset(w * 0.15, h * 0.22),
      radius: h * 0.55,
      color: const Color(0xFF1A3A6B),
      opacity: 0.45,
    );

    // ── Nebula glow — center-right (teal) ─────────────────────────────────
    _drawGlow(
      canvas,
      center: Offset(w * 0.82, h * 0.38),
      radius: h * 0.45,
      color: const Color(0xFF0D3D3A),
      opacity: 0.40,
    );

    // ── Nebula glow — bottom-center (indigo) ──────────────────────────────
    _drawGlow(
      canvas,
      center: Offset(w * 0.50, h * 0.88),
      radius: h * 0.50,
      color: const Color(0xFF1B1060),
      opacity: 0.35,
    );

    // ── Subtle aurora streak ───────────────────────────────────────────────
    _drawAurora(canvas, size);

    // ── Stars ──────────────────────────────────────────────────────────────
    for (final s in _stars) {
      canvas.drawCircle(
        Offset(s.x * w, s.y * h),
        s.radius,
        Paint()..color = Colors.white.withOpacity(s.opacity),
      );
    }

    // ── Bright accent stars ────────────────────────────────────────────────
    const brightStars = [
      (0.12, 0.08), (0.67, 0.14), (0.88, 0.61),
      (0.33, 0.44), (0.54, 0.72), (0.76, 0.88),
    ];
    for (final (dx, dy) in brightStars) {
      _drawBrightStar(canvas, Offset(dx * w, dy * h));
    }
  }

  void _drawGlow(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
    required double opacity,
  }) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color.withOpacity(opacity), color.withOpacity(0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  void _drawAurora(Canvas canvas, Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;

    path.moveTo(0, h * 0.35);
    path.cubicTo(
      w * 0.25, h * 0.25,
      w * 0.55, h * 0.45,
      w,        h * 0.30,
    );
    path.lineTo(w, h * 0.25);
    path.cubicTo(
      w * 0.55, h * 0.40,
      w * 0.25, h * 0.20,
      0,        h * 0.30,
    );
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFF1ABC9C).withOpacity(0.07),
            const Color(0xFF3DAEE9).withOpacity(0.10),
            const Color(0xFF9B59B6).withOpacity(0.07),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
  }

  void _drawBrightStar(Canvas canvas, Offset center) {
    // Glow halo
    canvas.drawCircle(
      center,
      4,
      Paint()
        ..color = Colors.white.withOpacity(0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // Core
    canvas.drawCircle(center, 1.6, Paint()..color = Colors.white);

    // Cross flare
    final flarePaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round;
    const arm = 6.0;
    canvas.drawLine(center.translate(-arm, 0), center.translate(arm, 0), flarePaint);
    canvas.drawLine(center.translate(0, -arm), center.translate(0, arm), flarePaint);
  }

  @override
  bool shouldRepaint(_WallpaperPainter old) => false;
}

class _Star {
  const _Star({
    required this.x,
    required this.y,
    required this.radius,
    required this.opacity,
  });
  final double x, y, radius, opacity;
}
