import 'dart:collection';

import 'accel_sample.dart';

/// Recognises a deliberate shake from a stream of accelerometer samples.
///
/// The rule is *oscillation*, not force. A magnitude threshold alone fires when
/// the phone is set down on a table; a shake is the only motion that reverses
/// direction several times in a row. So a shake is: at least [minReversals]
/// threshold crossings in alternating directions inside a [window].
///
/// Pure Dart — no plugins, no wall clock. Every input arrives through [add].
class ShakeRecognizer {
  ShakeRecognizer({
    this.threshold = mediumThreshold,
    this.minReversals = 3,
    this.window = const Duration(milliseconds: 700),
    this.cooldown = const Duration(milliseconds: 1200),
    this.minGapBetweenCrossings = const Duration(milliseconds: 80),
  }) : assert(threshold > 0, 'threshold must be positive'),
       assert(minReversals >= 2, 'a shake needs at least one reversal');

  /// Sensitivity presets, in m/s² of gravity-free acceleration.
  static const double lowThreshold = 15.0;
  static const double mediumThreshold = 12.0;
  static const double highThreshold = 9.0;

  /// Acceleration a sample must exceed to count as a crossing.
  final double threshold;

  /// How many alternating crossings make a shake.
  final int minReversals;

  /// Crossings older than this are forgotten.
  final Duration window;

  /// Motion is ignored for this long after firing, so one continuous shake
  /// produces exactly one result.
  final Duration cooldown;

  /// Two crossings closer together than this are sensor chatter, not motion.
  final Duration minGapBetweenCrossings;

  final Queue<_Crossing> _crossings = Queue<_Crossing>();
  Duration? _lastFiredAt;

  /// Feeds one sample in. Returns true exactly once per recognised shake.
  bool add(AccelSample sample) {
    final firedAt = _lastFiredAt;
    if (firedAt != null && sample.t - firedAt < cooldown) return false;

    if (sample.magnitude < threshold) return false;

    final axis = sample.dominantAxis;
    final sign = sample.signOf(axis);
    final previous = _crossings.isEmpty ? null : _crossings.last;

    if (previous != null) {
      // Too soon to be a real change of direction.
      if (sample.t - previous.t < minGapBetweenCrossings) return false;
      // Still travelling the same way — this is the same push, not a reversal.
      if (previous.axis == axis && previous.sign == sign) return false;
    }

    _crossings.addLast(_Crossing(sample.t, axis, sign));
    while (_crossings.isNotEmpty && sample.t - _crossings.first.t > window) {
      _crossings.removeFirst();
    }

    if (_crossings.length >= minReversals) {
      _crossings.clear();
      _lastFiredAt = sample.t;
      return true;
    }
    return false;
  }

  /// Forgets all motion history. Call when the detector is re-armed.
  void reset() {
    _crossings.clear();
    _lastFiredAt = null;
  }

  /// How close the user is to triggering a draw, 0..1. Drives the calibration
  /// meter and the "almost there" feedback on the draw screen.
  double get progress =>
      (_crossings.length / minReversals).clamp(0.0, 1.0).toDouble();
}

class _Crossing {
  const _Crossing(this.t, this.axis, this.sign);

  final Duration t;
  final AccelAxis axis;
  final int sign;
}
