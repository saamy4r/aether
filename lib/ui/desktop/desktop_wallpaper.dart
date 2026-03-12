import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';

class DesktopWallpaper extends StatelessWidget {
  const DesktopWallpaper({
    super.key,
    this.seed = 42,
    this.accentHue = 210.0,
    this.imagePath,
  });

  final int seed;
  final double accentHue;
  final String? imagePath; // if set, displays this image instead of procedural

  @override
  Widget build(BuildContext context) {
    if (imagePath != null) {
      return SizedBox.expand(
        child: Image.file(
          File(imagePath!),
          fit: BoxFit.cover,
          // Fall back to procedural if the file can't be read
          errorBuilder: (_, __, ___) => _ProceduralWallpaper(
            seed: seed,
            accentHue: accentHue,
          ),
        ),
      );
    }
    return _ProceduralWallpaper(seed: seed, accentHue: accentHue);
  }
}

class _ProceduralWallpaper extends StatelessWidget {
  const _ProceduralWallpaper({required this.seed, required this.accentHue});
  final int seed;
  final double accentHue;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WallpaperPainter(seed: seed, accentHue: accentHue),
      child: const SizedBox.expand(),
    );
  }
}

class _WallpaperPainter extends CustomPainter {
  _WallpaperPainter({required this.seed, required this.accentHue});

  final int seed;
  final double accentHue;

  // Cache star fields per seed so each VPS has a unique but consistent starfield
  static final Map<int, List<_Star>> _cache = {};

  List<_Star> get _stars => _cache.putIfAbsent(seed, () {
        final rng = Random(seed);
        return List.generate(220, (_) => _Star(
              x: rng.nextDouble(),
              y: rng.nextDouble(),
              radius: rng.nextDouble() * 1.4 + 0.3,
              opacity: rng.nextDouble() * 0.7 + 0.3,
            ));
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

    // ── Nebula glows — colors derived from accentHue ───────────────────────
    final nebulaColor1 =
        HSLColor.fromAHSL(1.0, accentHue, 0.6, 0.25).toColor();
    final nebulaColor2 =
        HSLColor.fromAHSL(1.0, (accentHue + 30) % 360, 0.5, 0.15).toColor();
    final nebulaColor3 = HSLColor.fromAHSL(
            1.0, (accentHue - 40 + 360) % 360, 0.7, 0.20)
        .toColor();

    _drawGlow(canvas,
        center: Offset(w * 0.15, h * 0.22),
        radius: h * 0.55,
        color: nebulaColor1,
        opacity: 0.45);

    _drawGlow(canvas,
        center: Offset(w * 0.82, h * 0.38),
        radius: h * 0.45,
        color: nebulaColor2,
        opacity: 0.40);

    _drawGlow(canvas,
        center: Offset(w * 0.50, h * 0.88),
        radius: h * 0.50,
        color: nebulaColor3,
        opacity: 0.35);

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
    canvas.drawCircle(
      center,
      4,
      Paint()
        ..color = Colors.white.withOpacity(0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(center, 1.6, Paint()..color = Colors.white);

    final flarePaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round;
    const arm = 6.0;
    canvas.drawLine(center.translate(-arm, 0), center.translate(arm, 0), flarePaint);
    canvas.drawLine(center.translate(0, -arm), center.translate(0, arm), flarePaint);
  }

  @override
  bool shouldRepaint(_WallpaperPainter old) =>
      old.seed != seed || old.accentHue != accentHue;
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
