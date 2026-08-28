import 'dart:math' as math;

import 'package:shake_it_up/domain/accel_sample.dart';

/// 50 Hz — the rate `SensorInterval.gameInterval` delivers.
const sampleInterval = Duration(milliseconds: 20);

/// Gravity-free readings, so a resting phone sits near zero.
List<AccelSample> _fromAxis(
  List<double> values, {
  required Duration from,
  bool onX = true,
}) {
  final samples = <AccelSample>[];
  for (var i = 0; i < values.length; i++) {
    final value = values[i];
    samples.add(
      onX
          ? AccelSample(value, 0.15, -0.1, from + sampleInterval * i)
          : AccelSample(0.15, -0.1, value, from + sampleInterval * i),
    );
  }
  return samples;
}

/// A sinusoidal shake along X — the motion the recogniser exists to catch.
List<AccelSample> shakeBurst({
  Duration from = Duration.zero,
  Duration duration = const Duration(milliseconds: 600),
  double amplitude = 16,
  Duration period = const Duration(milliseconds: 200),
}) {
  final values = <double>[];
  for (var t = Duration.zero; t < duration; t += sampleInterval) {
    final phase = 2 * math.pi * (t.inMicroseconds / period.inMicroseconds);
    values.add(amplitude * math.sin(phase));
  }
  return _fromAxis(values, from: from);
}

/// A phone at rest on a table, with sensor noise.
List<AccelSample> idle({
  Duration from = Duration.zero,
  Duration duration = const Duration(milliseconds: 600),
}) {
  final values = <double>[];
  var i = 0;
  for (var t = Duration.zero; t < duration; t += sampleInterval) {
    values.add(i.isEven ? 0.3 : -0.25);
    i++;
  }
  return _fromAxis(values, from: from);
}

/// Setting the phone down firmly: one hard spike in a single direction,
/// then ringing that never gets near the threshold again.
List<AccelSample> setDown({Duration from = Duration.zero}) => _fromAxis(
  const <double>[
    0.2, -0.1, 0.15, 0.0, //          resting in the hand
    6.0, 18.5, 22.0, 9.5, //          impact — all one direction
    -4.2, 3.1, -2.0, 1.4, -0.8, //    ringing, well under threshold
    0.2, -0.1, 0.0, 0.1, 0.0, //      settled
  ],
  from: from,
  onX: false,
);

/// Walking with the phone in hand: real oscillation, but nowhere near the
/// force of a deliberate shake.
List<AccelSample> walking({
  Duration from = Duration.zero,
  Duration duration = const Duration(seconds: 3),
}) => shakeBurst(
  from: from,
  duration: duration,
  amplitude: 6.5,
  period: const Duration(milliseconds: 520),
);

/// Slow rocking: strong enough, but the reversals are too far apart to land
/// inside one window.
List<AccelSample> slowRocking({
  Duration from = Duration.zero,
  Duration duration = const Duration(seconds: 4),
}) => shakeBurst(
  from: from,
  duration: duration,
  amplitude: 17,
  period: const Duration(milliseconds: 1600),
);
