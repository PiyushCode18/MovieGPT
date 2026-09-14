// MovieGPT — Premium Cinematic Startup Sting generator (pure-Dart DSP).
//
//   dart run tool/moviegpt_sting.dart
//
// Synthesizes a 5.0 s stereo (44.1 kHz / 16-bit PCM) WAV for the MovieGPT
// splash screen and writes it to assets/sounds/splash_sound.wav.
//
// Sound design map (syncs with the MovieGPT "M" logo animation):
//   0.0–1.0 s   near-silence -> deep sub-bass drone + dark rumble
//   1.0–2.5 s   rising low whoosh + gliding futuristic tone (tension build)
//   2.5 s       cinematic bass impact (logo completes) + metallic resonance,
//               wide stereo expansion
//   3.5–5.0 s   spacious dark reverb tail, shimmering AI sparkle, fade to
//               silence
//
// Original composition for MovieGPT. No melodies, vocals, or drums — pure
// cinematic sound design. Master peak-normalized to ~0.88 FS (no clipping).
//
// DSP-style short identifiers (_SR, svfL_B, ...) are intentional and match the
// conventions used across this file's algorithms.
// ignore_for_file: constant_identifier_names, non_constant_identifier_names

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const int _SR = 44100;
const double _DUR = 5.0;
const int _N = _SR * 5; // 220500 samples = 5.0 s

void main() {
  final wav = _renderSting();
  final outDir = Directory('assets/sounds');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);
  final outFile = File('assets/sounds/splash_sound.wav');
  outFile.writeAsBytesSync(wav);
  // ignore: avoid_print
  print('Generated ${outFile.path} (${wav.length} bytes, '
      '$_DUR s stereo 44.1 kHz / 16-bit PCM)');
  _verifyAudio(outFile.path);
}

/// Renders the full stereo sting and returns the .wav file bytes.
Uint8List _renderSting() {
  final left = Float64List(_N);
  final right = Float64List(_N);
  final wetL = Float64List(_N);
  final wetR = Float64List(_N);
  final rng = Random(20240214); // deterministic for reproducibility

  // ---- shared interpolation helpers --------------------------------------
  double linRamp(double t, double t0, double t1) {
    if (t <= t0) return 0.0;
    if (t >= t1) return 1.0;
    return (t - t0) / (t1 - t0);
  }

  double expDecay(double t, double tau) => exp(-t / tau);

  double logFreq(double t, double t0, double f0, double t1, double f1) {
    final x = ((t - t0) / (t1 - t0)).clamp(0.0, 1.0);
    return f0 * pow(f1 / f0, x);
  }
// ---- persistent oscillator / filter states ------------------------------
  double phDroneA = 0, phDroneB = 0, phDroneC = 0;
  double brL = 0, brR = 0;
  double tonePhL = 0, tonePhR = 0, tonePhC = 0;
  double boomPhL = 0.16, boomPhR = -0.16; // slight phase offset = wide bass
  // whoosh SVF states
  double svfL_L = 0, svfL_B = 0, svfL_H = 0;
  double svfR_L = 0, svfR_B = 0, svfR_H = 0;
  double bodyL = 0, bodyR = 0;
  double prevNoiseL = 0, prevNoiseR = 0;

  // metallic partial frequencies (inharmonic gong set) + stereo pan
  const List<double> metalF = [1180, 1760, 2490, 3350];
  const List<double> metalStart = [0.000, 0.005, 0.011, 0.016];
  const List<double> metalAmp = [0.075, 0.062, 0.048, 0.030];
  const List<double> metalPan = [-0.55, 0.42, -0.30, 0.65];
  final metalPh =
      List<double>.generate(4, (_) => rng.nextDouble() * 2 * pi);
  final metalDet = List<double>.generate(
      4, (_) => 1 + (rng.nextDouble() - 0.5) * 0.01);

  // --------------------------------------------------------------------------
  // synth loop
  // --------------------------------------------------------------------------
  for (var i = 0; i < _N; i++) {
    final double t = i / _SR;
    final double tSinceBoom = t - 2.5;

    // LAYER A — sub-bass drone + dark rumble (0.0 -> 5.0 s)
    final double droneEnv =
        linRamp(t, 0.35, 1.0) * (t > 3.5 ? expDecay(t - 3.5, 1.4) : 1.0);
    final double lfo = 1.0 + 0.16 * sin(2 * pi * 1.3 * t);
    phDroneA += 2 * pi * 36.5 / _SR;
    phDroneB += 2 * pi * 54.75 / _SR;
    phDroneC += 2 * pi * 73.0 / _SR;
    final double dA = sin(phDroneA);
    final double dB = sin(phDroneB + 0.5 * sin(2 * pi * 0.37 * t));
    final double dC = sin(phDroneC + 0.35 * sin(2 * pi * 0.29 * t));
    final double drone = (dA * 0.55 + dB * 0.32 + dC * 0.13) * droneEnv * lfo;
    final double panDrift = 0.06 * sin(2 * pi * 0.23 * t);
    final double droneL = drone * (0.94 + panDrift) * 0.30;
    final double droneR = drone * (0.94 - panDrift) * 0.30;

    // brown-ish rumble
    final double wnL = rng.nextDouble() * 2 - 1;
    final double wnR = rng.nextDouble() * 2 - 1;
    brL = brL * 0.9968 + wnL * 0.020;
    brR = brR * 0.9968 + wnR * 0.020;
    final double rumL = brL * 0.085 * droneEnv;
    final double rumR = brR * 0.085 * droneEnv;

    // LAYER B — rising low-frequency whoosh (1.0 -> 3.3 s)
    double whoEnv = 0.0;
    if (t > 1.0 && t < 3.3) {
      if (t < 2.45) {
        whoEnv = linRamp(t, 1.0, 2.45);
      } else {
        whoEnv = 0.92 * expDecay(t - 2.45, 0.30);
      }
    }
    double whooshL = 0, whooshR = 0;
    if (whoEnv > 0.001) {
      final double fBp = logFreq(t, 1.0, 260, 2.5, 3400);
      final double fBpLp = logFreq(t, 1.0, 220, 2.5, 900);
      final double fBpN = 2 * sin(pi * fBp / _SR);
      final double aBody = 1 - exp(-2 * pi * fBpLp / _SR);
      final double dampBp = 0.52; // BP Q ~ 1.9
      final double nL = rng.nextDouble() * 2 - 1;
      final double nR = rng.nextDouble() * 2 - 1;
      // SVF bandpass with slightly different damping L/R (width)
      svfL_L += fBpN * svfL_B;
      svfL_H = nL - svfL_L - dampBp * svfL_B;
      svfL_B += fBpN * svfL_H;
      svfR_L += fBpN * svfR_B;
      svfR_H = nR - svfR_L - (dampBp * 1.09) * svfR_B;
      svfR_B += fBpN * svfR_H;
      // one-pole low body
      bodyL += aBody * (nL - bodyL);
      bodyR += aBody * (nR - bodyR);
      prevNoiseL = 0.78 * prevNoiseL + 0.22 * nL;
      prevNoiseR = 0.78 * prevNoiseR + 0.22 * nR;
      whooshL = svfL_B * 0.155 * whoEnv + bodyL * 0.085 * whoEnv;
      whooshR = svfR_B * 0.155 * whoEnv + bodyR * 0.085 * whoEnv;
    }
// LAYER C — gliding futuristic tone (1.05 -> 3.0 s)  196 -> 392 Hz
    double toneEnv = 0.0;
    if (t > 1.05 && t < 3.0) {
      if (t < 2.45) {
        toneEnv = linRamp(t, 1.05, 2.45);
      } else {
        toneEnv = expDecay(t - 2.45, 0.22);
      }
    }
    double toneL = 0, toneR = 0;
    if (toneEnv > 0.001) {
      final double fA = logFreq(t, 1.05, 196, 2.5, 392);
      tonePhL += 2 * pi * (fA * 0.997) / _SR;
      tonePhR += 2 * pi * (fA * 1.003) / _SR;
      tonePhC += 2 * pi * (fA * 1.5) / _SR;
      final double trem = 1.0 + 0.10 * sin(2 * pi * 3.9 * t);
      final double e = toneEnv * trem * 0.10;
      toneL = (0.72 * sin(tonePhL) + 0.22 * sin(2 * tonePhL) +
          0.15 * sin(tonePhC)) *
          e;
      toneR = (0.72 * sin(tonePhR) + 0.22 * sin(2 * tonePhR) +
          0.15 * sin(tonePhC)) *
          e;
    }

    // LAYER D — cinematic impact: boom + transient + metallic resonance
    double boomL = 0, boomR = 0, transN = 0, metal = 0;
    if (tSinceBoom >= 0 && tSinceBoom < 2.6) {
      final double dt = tSinceBoom;
      final double fBoom = 150 * exp(-dt * 4.2) + 36;
      boomPhL += 2 * pi * fBoom / _SR;
      boomPhR += 2 * pi * fBoom / _SR;
      final double bEnv = dt < 0.002 ? dt / 0.002 : expDecay(dt, 0.20);
      boomL = sin(boomPhL) * bEnv * 0.85;
      boomR = sin(boomPhR) * bEnv * 0.85;
      // crisp attack transient (8 ms)
      if (dt < 0.02) {
        final double nT = rng.nextDouble() * 2 - 1;
        final double g =
            min(1.0, dt / 0.001) * expDecay(dt, 0.004);
        transN = nT * 0.16 * g;
      }
      // metallic gong partials (subtle, wide)
      for (var k = 0; k < 4; k++) {
        if (dt >= metalStart[k]) {
          final double envK =
              expDecay(dt - metalStart[k], 0.80) * metalAmp[k];
          final double m = sin(2 * pi * metalF[k] * metalDet[k] * t +
              metalPh[k]);
          metal += m * envK;
          boomL += m * envK * (0.5 + 0.16 * metalPan[k]);
          boomR += m * envK * (0.5 - 0.16 * metalPan[k]);
        }
      }
    }
    final double impactL = boomL + transN;
    final double impactR = boomR + transN;

    // LAYER E — AI shimmer sparkles (3.5 -> 4.7 s)
    double shimmerL = 0, shimmerR = 0;
    const List<double> shF = [1880, 2510, 3200, 4180, 5660, 7450];
    const List<double> shStart = [3.55, 3.70, 3.85, 4.00, 4.15, 4.30];
    const List<double> shAmp = [0.050, 0.045, 0.040, 0.033, 0.026, 0.018];
    for (var k = 0; k < 6; k++) {
      if (t > shStart[k]) {
        final double dtSh = t - shStart[k];
        final double envK = expDecay(dtSh, 0.55) * shAmp[k];
        final double fGlide =
            shF[k] * (1 - 0.018 * min(1.0, dtSh / 0.9));
        final double phase = 2 * pi * fGlide * t + k * 1.7;
        final double s = sin(phase) * envK;
        if (k.isEven) {
          shimmerL += s * 0.78;
          shimmerR += s * 0.35;
        } else {
          shimmerL += s * 0.34;
          shimmerR += s * 0.80;
        }
      }
    }

    // BUSES — dry + wet (reverb) send
    left[i] = droneL + rumL + whooshL + toneL + impactL + shimmerL;
    right[i] = droneR + rumR + whooshR + toneR + impactR + shimmerR;

    wetL[i] = (boomL * 0.55 + transN * 0.30 + metal * 0.40 +
        (whooshL + toneL) * 0.35 + droneL * 0.15 + shimmerL * 0.55);
    wetR[i] = (boomR * 0.55 + transN * 0.30 + metal * 0.40 +
        (whooshR + toneR) * 0.35 + droneR * 0.15 + shimmerR * 0.55);
  }

  // --------------------------------------------------------------------------
  // spacious dark reverb tail (Schroeder, decorrelated L/R)
  // --------------------------------------------------------------------------
  final revL = _schroeder(wetL, 1.0);
  final revR = _schroeder(wetR, 1.004);

  // --------------------------------------------------------------------------
  // master: dry + wet mix, global fade, DC block, peak normalize
  // --------------------------------------------------------------------------
  final outL = Float64List(_N);
  final outR = Float64List(_N);
  double dcOutL = 0, dcOutR = 0, prevOutL = 0, prevOutR = 0;
  double peak = 0.0;
  for (var i = 0; i < _N; i++) {
    final double t = i / _SR;
    double fade = 1.0;
    if (t > 4.5) {
      final double x = ((t - 4.5) / 0.45).clamp(0.0, 1.0);
      fade = 0.5 * (1 + cos(pi * x));
    }
    final double mixL = left[i] + 0.55 * revL[i];
    final double mixR = right[i] + 0.55 * revR[i];
    // DC blocker (~0.7 Hz high-pass)
    dcOutL = 0.9999 * dcOutL + (mixL - prevOutL);
    dcOutR = 0.9999 * dcOutR + (mixR - prevOutR);
    prevOutL = mixL;
    prevOutR = mixR;
    outL[i] = dcOutL * fade;
    outR[i] = dcOutR * fade;
    peak = max(peak, max(outL[i].abs(), outR[i].abs()));
  }
  final double norm = 0.88 / (peak + 1e-12);
  for (var i = 0; i < _N; i++) {
    outL[i] *= norm;
    outR[i] *= norm;
  }

  return _stereoToWav(outL, outR, _SR);
}
// ----------------------------------------------------------------------------
// Schroeder reverb (4 parallel combs -> 2 cascaded allpasses)
// ----------------------------------------------------------------------------
Float64List _schroeder(Float64List input, double scale) {
  final n = input.length;
  final out = Float64List(n);
  final combs = <_Comb>[
    _Comb((0.047 * _SR).round(), 0.80, 0.32),
    _Comb((0.062 * _SR * scale).round(), 0.80, 0.30),
    _Comb((0.073 * _SR * scale).round(), 0.82, 0.34),
    _Comb((0.091 * _SR * scale).round(), 0.82, 0.28),
  ];
  final allpasses = <_Allpass>[
    _Allpass((0.0051 * _SR).round(), 0.5),
    _Allpass((0.0017 * _SR).round(), 0.5),
  ];
  for (var i = 0; i < n; i++) {
    final double x = input[i] * 0.32;
    double s = 0;
    for (final c in combs) {
      s += c.process(x);
    }
    for (final a in allpasses) {
      s = a.process(s);
    }
    out[i] = s;
  }
  return out;
}

class _Comb {
  final Float64List buf;
  int idx = 0;
  final double g;
  final double damp;
  _Comb(int size, this.g, this.damp) : buf = Float64List(size);

  double process(double x) {
    final d = buf[idx];
    final y = d;
    // Stable Schroeder comb: store input + g*previous echo (feedback = g < 1).
    // No extra blend-back so the loop gain stays strictly below unity.
    buf[idx] = x + g * d;
    idx = (idx + 1) % buf.length;
    return y;
  }
}

class _Allpass {
  final Float64List buf;
  int idx = 0;
  final double g;
  _Allpass(int size, this.g) : buf = Float64List(size);

  double process(double x) {
    final wM = buf[idx];
    final y = wM - g * x;
    buf[idx] = x + g * y;
    idx = (idx + 1) % buf.length;
    return y;
  }
}

/// Encodes stereo Float64 buffers into a 16-bit PCM WAV file.
Uint8List _stereoToWav(Float64List l, Float64List r, int sr) {
  final int n = l.length;
  final int dataLength = n * 2 * 2; // 2 ch x 2 bytes
  final int byteRate = sr * 2 * 2;
  final buffer = BytesBuilder();

  buffer.add(_ansi('RIFF'));
  buffer.add(_le32(36 + dataLength));
  buffer.add(_ansi('WAVE'));
  buffer.add(_ansi('fmt '));
  buffer.add(_le32(16));
  buffer.add(_le16(1)); // PCM
  buffer.add(_le16(2)); // channels
  buffer.add(_le32(sr));
  buffer.add(_le32(byteRate));
  buffer.add(_le16(4)); // block align
  buffer.add(_le16(16)); // bits
  buffer.add(_ansi('data'));
  buffer.add(_le32(dataLength));

  for (var i = 0; i < n; i++) {
    final int a = _to16(l[i]);
    final int b = _to16(r[i]);
    buffer.addByte(a & 0xFF);
    buffer.addByte((a >> 8) & 0xFF);
    buffer.addByte(b & 0xFF);
    buffer.addByte((b >> 8) & 0xFF);
  }
  return buffer.toBytes();
}

int _to16(double v) {
  var s = (v * 32767.0).round();
  if (s > 32767) s = 32767;
  if (s < -32768) s = -32768;
  return s;
}

Uint8List _ansi(String s) => Uint8List.fromList(s.codeUnits);
Uint8List _le16(int v) {
  final b = Uint8List(2);
  final bd = ByteData.view(b.buffer);
  bd.setUint16(0, v & 0xFFFF, Endian.little);
  return b;
}
Uint8List _le32(int v) {
  final b = Uint8List(4);
  final bd = ByteData.view(b.buffer);
  bd.setUint32(0, v & 0xFFFFFFFF, Endian.little);
  return b;
}

/// Reads the generated WAV back and prints objective measurements.
void _verifyAudio(String path) {
  final data = File(path).readAsBytesSync();
  final bd = ByteData.view(data.buffer);
  final int sr = bd.getUint32(24, Endian.little);
  final int channels = bd.getUint16(22, Endian.little);
  final int bits = bd.getUint16(34, Endian.little);
  final int dataLen = bd.getUint32(40, Endian.little);
  final int frames = (dataLen ~/ (channels * (bits ~/ 8)));
  final double duration = frames / sr;

  // peak + per-second RMS
  final sec = duration.ceil();
  final rms = List<double>.filled(sec, 0.0);
  final counts = List<int>.filled(sec, 0);
  double peak = 0;
  for (var f = 0; f < frames; f++) {
    final int off = 44 + f * channels * 2;
    double l = bd.getInt16(off, Endian.little) / 32768.0;
    double r = channels > 1 ? bd.getInt16(off + 2, Endian.little) / 32768.0 : l;
    final double s = (l.abs() > r.abs()) ? l : r;
    peak = max(peak, s.abs());
    final int secIdx = (f ~/ sr).clamp(0, sec - 1);
    rms[secIdx] += (l * l + r * r) / channels;
    counts[secIdx] += 1;
  }
  final sb = StringBuffer()
    ..writeln('WAV inspected: $sr Hz, $channels ch, $bits bit, '
        '${duration.toStringAsFixed(2)} s, peak ${peak.toStringAsFixed(3)} FS')
    ..write('RMS/1s: ');
  for (var k = 0; k < sec; k++) {
    final v = sqrt(rms[k] / (counts[k] + 1e-9));
    sb.write('$k-${k + 1}s=${v.toStringAsFixed(3)} ');
  }
  // ignore: avoid_print
  print(sb.toString());
}