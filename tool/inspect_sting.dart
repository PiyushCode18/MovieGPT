// Quick waveform inspection for the generated sting WAV.
//   dart run tool/inspect_sting.dart
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:typed_data';

void main() {
  final data = File('assets/sounds/splash_sound.wav').readAsBytesSync();
  final bd = ByteData.view(data.buffer);
  final sr = bd.getUint32(24, Endian.little);
  final ch = bd.getUint16(22, Endian.little);
  final frames = (bd.getUint32(40, Endian.little) ~/ (ch * 2));

  double peak = 0;
  int peakFrame = 0;
  for (var f = 0; f < frames; f++) {
    final v = bd.getInt16(44 + f * ch * 2, Endian.little).abs() / 32768.0;
    if (v > peak) {
      peak = v;
      peakFrame = f;
    }
  }
  print('global peak=${peak.toStringAsFixed(3)} FS at t='
      '${(peakFrame / sr).toStringAsFixed(2)}s');

  final sb = StringBuffer()..writeln('Peak/0.1s:');
  var winPeak = 0.0;
  const int hop = 4410; // 0.1 s at 44100 Hz
  for (var f = 0; f < frames; f++) {
    final v = bd.getInt16(44 + f * ch * 2, Endian.little).abs() / 32768.0;
    if (v > winPeak) winPeak = v;
    if ((f + 1) % hop == 0) {
      sb.write('${(f / sr).toStringAsFixed(1)}s=${winPeak.toStringAsFixed(2)} ');
      winPeak = 0.0;
    }
  }
  print(sb.toString());
}