import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The app logo: a gradient squircle holding a coin ring, three growth bars and the amber xp spark.
/// Every part takes a 0..1 progress so the splash screen can build it piece by piece.
/// Same geometry as android/app/src/main/res/drawable/ic_launcher_foreground.xml.
class LogoPainter extends CustomPainter {
  LogoPainter({
    this.tile = 1,
    this.ring = 1,
    this.bars = 1,
    this.spark = 1,
    this.tileRotation = 0,
    this.showTile = true,
  });

  final double tile;
  final double ring;
  final double bars;
  final double spark;
  final double tileRotation;
  final bool showTile;

  static const _gradient = [Color(0xFF22C55E), Color(0xFF16A34A), Color(0xFF0B7A3B)];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 108;
    canvas.save();
    canvas.translate((size.width - 108 * s) / 2, (size.height - 108 * s) / 2);
    canvas.scale(s);

    if (showTile && tile > 0) {
      canvas.save();
      canvas.translate(54, 54);
      canvas.rotate(tileRotation);
      canvas.scale(tile);
      canvas.translate(-54, -54);
      final rect = const Rect.fromLTWH(0, 0, 108, 108);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(32)),
        Paint()
          ..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: _gradient, stops: [0, 0.6, 1])
              .createShader(rect),
      );
      // soft top highlight for depth
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(32)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0)],
          ).createShader(rect),
      );
      canvas.restore();
    }

    // ring: starts at -15deg and sweeps 300deg clockwise, leaving a gap at the top right
    if (ring > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: const Offset(54, 54), radius: 20),
        -15 * math.pi / 180,
        300 * math.pi / 180 * ring,
        false,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.5
          ..strokeCap = StrokeCap.round,
      );
    }

    // bars grow up one after another
    const tops = [56.5, 52.0, 47.5];
    for (var i = 0; i < 3; i++) {
      final p = Curves.easeOutBack.transform(((bars * 3) - i).clamp(0.0, 1.0));
      if (p <= 0) continue;
      final left = 43 + i * 8.5;
      final top = 62 - (62 - tops[i] + 2.5) * p;
      canvas.drawRRect(
        RRect.fromLTRBAndCorners(left, top, left + 5, 62, topLeft: const Radius.circular(2.5), topRight: const Radius.circular(2.5)),
        Paint()..color = Colors.white,
      );
    }

    if (spark > 0) {
      const c = Offset(68.14, 39.86);
      canvas.drawCircle(c, 3.8 * Curves.elasticOut.transform(spark.clamp(0, 1)), Paint()..color = const Color(0xFFFFB547));
      if (spark < 1) {
        canvas.drawCircle(
          c,
          3.8 + 10 * spark,
          Paint()
            ..color = const Color(0xFFFFB547).withValues(alpha: (1 - spark) * 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(LogoPainter old) =>
      old.tile != tile || old.ring != ring || old.bars != bars || old.spark != spark || old.tileRotation != tileRotation || old.showTile != showTile;
}

class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 64});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(dimension: size, child: CustomPaint(painter: LogoPainter()));
}
