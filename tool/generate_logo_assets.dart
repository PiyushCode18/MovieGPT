// Logo art pipeline: renders the shared MovieGPT emblem painter to PNG assets.
//
// Run with:
//   flutter test tool/generate_logo_assets.dart
//
// Outputs (1024x1024, transparent background):
//   assets/images/moviegpt_logo.png            - emblem at ~98% (full badge)
//   assets/images/moviegpt_logo_transparent.png- same artwork, transparent bg
//   assets/images/moviegpt_logo_foreground.png - emblem at ~62% (adaptive icon
//                                                foreground safe zone)
//
// Also regenerates the Android adaptive-icon foregrounds:
//   android/app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/
//     ic_launcher_foreground.png  (108/162/216/324/432 px)
import 'dart:io';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moviegpt_app/widgets/moviegpt_logo.dart';

Future<void> _renderEmblemPng(
  String path,
  int pixels,
  double fraction,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    Rect.fromLTWH(0, 0, pixels.toDouble(), pixels.toDouble()),
  );

  // Place the 1024-unit emblem design into the center <fraction> of the image.
  final offset = (pixels * (1 - fraction)) / 2;
  canvas.translate(offset, offset);
  canvas.scale(pixels * fraction / 1024.0);

  paintMovieGptEmblem(canvas, const Size(1024, 1024), glow: 0.0);

  final picture = recorder.endRecording();
  final image = await picture.toImage(pixels, pixels);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) {
    throw StateError('Failed to encode PNG for $path');
  }
  final file = File(path);
  file.createSync(recursive: true);
  file.writeAsBytesSync(byteData.buffer.asUint8List());
  assert(file.lengthSync() > 0);
  // ignore: avoid_print
  print('Generated $path (${file.lengthSync()} bytes)');
}

const _adaptiveForegrounds = <String, int>{
  'android/app/src/main/res/mipmap-mdpi/ic_launcher_foreground.png': 108,
  'android/app/src/main/res/mipmap-hdpi/ic_launcher_foreground.png': 162,
  'android/app/src/main/res/mipmap-xhdpi/ic_launcher_foreground.png': 216,
  'android/app/src/main/res/mipmap-xxhdpi/ic_launcher_foreground.png': 324,
  'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png': 432,
};

void main() {
  test('render MovieGPT logo PNG assets', () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    await _renderEmblemPng('assets/images/moviegpt_logo.png', 1024, 0.98);
    await _renderEmblemPng(
      'assets/images/moviegpt_logo_transparent.png',
      1024,
      0.98,
    );
    await _renderEmblemPng(
      'assets/images/moviegpt_logo_foreground.png',
      1024,
      0.62,
    );

    // Emblem sits inside Android's 66dp adaptive-icon safe zone (62% of 108dp).
    for (final entry in _adaptiveForegrounds.entries) {
      await _renderEmblemPng(entry.key, entry.value, 0.62);
    }
  });
}