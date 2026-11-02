// Renders the launcher / store icons from LogoPainter so they always match the in-app logo.
// Run: flutter test tool/render_icons_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:expense_tracker/widgets/logo_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _render(String path, int size, {bool square = false}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final s = size.toDouble();
  if (square) {
    // store icon: full-bleed square, the store applies its own mask
    canvas.drawRect(
      Rect.fromLTWH(0, 0, s, s),
      Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF22C55E), Color(0xFF16A34A), Color(0xFF0B7A3B)], stops: [0, 0.6, 1]).createShader(Rect.fromLTWH(0, 0, s, s)),
    );
    // glyph scaled up to fill the square like the adaptive icon does
    canvas.save();
    canvas.translate(-s * 0.15, -s * 0.15);
    LogoPainter(showTile: false).paint(canvas, Size(s * 1.3, s * 1.3));
    canvas.restore();
  } else {
    LogoPainter().paint(canvas, Size(s, s));
  }
  final image = await recorder.endRecording().toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path)..createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  test('render icons', () async {
    const res = 'android/app/src/main/res';
    const sizes = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192};
    for (final e in sizes.entries) {
      await _render('$res/mipmap-${e.key}/ic_launcher.png', e.value);
    }
    await _render('store_assets/play_store_icon_512.png', 512, square: true);
    await _render('store_assets/logo_1024.png', 1024);
  });
}
