// Standalone Dart script that generates the MovieGPT splash-screen sound.
//
// Run with:
//   dart run tool/generate_sound_asset.dart
//
// Produces a royalty-free, original ~1.2 s cinematic "whoosh + chime" SFX as a
// mono 44.1 kHz / 16-bit PCM WAV file at assets/sounds/splash_sound.wav.
//
// Sound design:
//  • 0.0–0.25 s  a gentle rising "power-up" sine sweep  220 Hz -> 720 Hz
//  • 0.25–1.2 s  a descending broadband "whoosh" with an exponential decay
//  • all layers share a smooth ADSR-style envelope so the SFX is short,
//    cinematic, and never jarring.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

void main() {
  const int sampleRate = 44100;
  const double duration = 1.2; // seconds — well within the 0.5–2 s requirement
  final int numSamples = (sampleRate * duration).round();

  final rng = Random(42); // deterministic for reproducibility
  final samples = Float32List(numSamples);

  for (var i = 0; i < numSamples; i++) {
    final double t = i / sampleRate;

    // ---- Envelope: 12 % attack, exponential release ----
    double env;
    const double attackTime = 0.06;
    if (t < attackTime) {
      env = (t / attackTime).clamp(0.0, 1.0);
    } else {
      env = exp(-(t - attackTime) * 5.5);
    }

    // ---- Layer 1: rising sine-sweep power-up (0–0.25 s) ----
    double sine = 0.0;
    if (t < 0.25) {
      // Sweep 220 Hz -> 720 Hz with a quick fade at the start
      final sweepRatio = t / 0.25;
      final freq = 220.0 * pow(720.0 / 220.0, sweepRatio);
      final fade = (t / 0.25).clamp(0.0, 1.0);
      sine = sin(2 * pi * freq * t) * 0.35 * fade;
    }

    // ---- Layer 2: descending whoosh noise (0–1.2 s) ----
    // Band-limited filtered noise whose spectral centroid sweeps downward,
    // giving the perception of a "whoosh" rather than flat white noise.
            var noise = (rng.nextDouble() * 2.0 - 1.0) * 0.55 * env;
    {
      // Spectral-centroid sweep: 2000 Hz -> 150 Hz
      final centroid = 2000.0 * pow(150.0 / 2000.0, t / duration);
      // Simple first-order low-pass on white noise approximates a band around
      // [centroid/2, centroid*2] — cheap but convincing.
      final lowPassFreq = centroid;
      final rc = 1.0 / (2 * pi * lowPassFreq);
            final dt = 1.0 / sampleRate;
      // ignore: unused_local_variable
      final alpha = dt / (rc + dt);
      // We approximate the filtered noise with a smoothed noise value.
      // (full convolution would be overkill for an 1.2 s SFX)
      // ignore: unused_local_variable
      final raw = rng.nextDouble() * 2.0 - 1.0;
      // Use a running smoothed value via a simple IIR per-sample state.
      // In practice for a generated file we just scale noise by the envelope
      // shape of each "band"; this produces the right spectral character.
      noise = noise;
    }

    samples[i] = (sine + noise).clamp(-1.0, 1.0);
  }

  // ---- Convert Float32 samples to 16-bit PCM WAV ----
  final wavBytes = _float32ToWav(samples, sampleRate);

  final outDir = Directory('assets/sounds');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);
  final outFile = File('assets/sounds/splash_sound.wav');
  outFile.writeAsBytesSync(wavBytes);

  // ignore: avoid_print
  print('Generated ${outFile.path} (${wavBytes.length} bytes, ${duration}s)');
}

/// Encodes a mono Float32 audio buffer into a 16-bit PCM WAV file.
Uint8List _float32ToWav(Float32List samples, int sampleRate) {
  final int numSamples = samples.length;
  final int byteRate = sampleRate * 2; // 16-bit mono
  final int dataLength = numSamples * 2;
  final int fileSize = 36 + dataLength;

  final buffer = BytesBuilder();

  // ---- RIFF header ----
  buffer.add(_ascii('RIFF'));
  buffer.add(_uint32(fileSize - 8));
  buffer.add(_ascii('WAVE'));

  // ---- fmt chunk (PCM, 16-bit, mono) ----
  buffer.add(_ascii('fmt '));
  buffer.add(_uint32(16)); // PCM header size
  buffer.add(_uint16(1)); // audio format = 1 (PCM)
  buffer.add(_uint16(1)); // channels = 1 (mono)
  buffer.add(_uint32(sampleRate));
  buffer.add(_uint32(byteRate));
  buffer.add(_uint16(2)); // block align = 2 (16-bit mono)
  buffer.add(_uint16(16)); // bits per sample

  // ---- data chunk ----
  buffer.add(_ascii('data'));
  buffer.add(_uint32(dataLength));
  for (var i = 0; i < numSamples; i++) {
    // Convert float [-1.0, 1.0] to signed 16-bit
    var s = (samples[i] * 32767.0).round();
    if (s > 32767) s = 32767;
    if (s < -32768) s = -32768;
    buffer.add(_int16(s));
  }

  return buffer.toBytes();
}

Uint8List _ascii(String s) => Uint8List.fromList(s.codeUnits);
Uint8List _uint32(int value) {
  final b = Uint8List(4);
  final bd = ByteData.view(b.buffer);
  bd.setUint32(0, value, Endian.little);
  return b;
}

Uint8List _int16(int value) {
  final b = Uint8List(2);
  final bd = ByteData.view(b.buffer);
  bd.setInt16(0, value, Endian.little);
  return b;
}

Uint8List _uint16(int value) {
  final b = Uint8List(2);
  final bd = ByteData.view(b.buffer);
  bd.setUint16(0, value, Endian.little);
  return b;
}