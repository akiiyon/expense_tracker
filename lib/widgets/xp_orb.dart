import 'dart:math' as math;

import 'package:flutter/material.dart';

enum OrbMood { idle, listening, thinking, speaking }

/// xp's face: a living aurora blob that breathes when idle, swells with your voice
/// while listening, swirls while thinking and ripples while speaking.
class XpOrb extends StatefulWidget {
  const XpOrb({super.key, this.size = 56, this.mood = OrbMood.idle, this.level = 0});

  final double size;
  final OrbMood mood;

  /// Microphone level 0..1 while listening.
  final double level;

  @override
  State<XpOrb> createState() => _XpOrbState();
}

class _XpOrbState extends State<XpOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
  double _level = 0;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          // ease the mic level so the orb doesn't jitter
          _level += (widget.level - _level) * 0.25;
          return CustomPaint(
            size: Size.square(widget.size),
            painter: _OrbPainter(t: _c.value, mood: widget.mood, level: _level),
          );
        },
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({required this.t, required this.mood, required this.level});

  final double t;
  final OrbMood mood;
  final double level;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final base = size.shortestSide / 2;
    final time = t * 2 * math.pi;
    final speed = switch (mood) { OrbMood.thinking => 6.0, OrbMood.speaking => 4.0, OrbMood.listening => 3.0, _ => 1.0 };

    var r = base * 0.78;
    switch (mood) {
      case OrbMood.idle:
        r *= 1 + 0.04 * math.sin(time * 4);
      case OrbMood.listening:
        r *= 0.92 + 0.14 * level;
      case OrbMood.thinking:
        r *= 0.95 + 0.03 * math.sin(time * 12);
      case OrbMood.speaking:
        r *= 0.94 + 0.06 * math.sin(time * 18).abs();
    }

    // outer glow
    canvas.drawCircle(
      c,
      r * 1.18,
      Paint()
        ..shader = RadialGradient(colors: [const Color(0xFF14B8A6).withValues(alpha: 0.35), Colors.transparent]).createShader(Rect.fromCircle(center: c, radius: r * 1.25)),
    );

    // listening ripples
    if (mood == OrbMood.listening || mood == OrbMood.speaking) {
      for (var i = 0; i < 2; i++) {
        final p = (t * speed * 2 + i / 2) % 1.0;
        canvas.drawCircle(
          c,
          r * (1 + p * 0.35),
          Paint()
            ..color = const Color(0xFF4ADE80).withValues(alpha: (1 - p) * 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }

    // wobbly blob body
    final path = Path();
    const points = 64;
    for (var i = 0; i <= points; i++) {
      final a = i / points * 2 * math.pi;
      final wobble = 1 +
          0.045 * math.sin(a * 3 + time * speed) +
          0.035 * math.sin(a * 5 - time * speed * 1.3) +
          (mood == OrbMood.listening ? 0.06 * level * math.sin(a * 7 + time * 9) : 0);
      final p = c + Offset(math.cos(a), math.sin(a)) * r * wobble;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();

    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawPath(
      path,
      Paint()
        ..shader = SweepGradient(
          transform: GradientRotation(time * speed * 0.5),
          colors: const [Color(0xFF22C55E), Color(0xFF14B8A6), Color(0xFFFFB547), Color(0xFF00C896), Color(0xFF22C55E)],
        ).createShader(rect),
    );
    // inner light so it feels like a glossy sphere
    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 0.9,
          colors: [Colors.white.withValues(alpha: 0.55), Colors.white.withValues(alpha: 0.05), Colors.transparent],
          stops: const [0, 0.45, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_OrbPainter old) => true;
}
