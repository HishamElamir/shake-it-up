import 'dart:math' as math;

/// Which axis carried the most acceleration in a sample.
enum AccelAxis { x, y, z }

/// A single accelerometer reading with gravity already removed.
///
/// The timestamp travels *with* the sample instead of being read from a clock.
/// That is what lets [ShakeRecognizer] be replayed at any speed in a test with
/// no timers and no flake.
class AccelSample {
  const AccelSample(this.x, this.y, this.z, this.t);

  final double x;
  final double y;
  final double z;

  /// Time since the stream started. Monotonic, but never assumed to be.
  final Duration t;

  double get magnitude => math.sqrt(x * x + y * y + z * z);

  /// The axis with the largest absolute component — the direction the device
  /// is being moved along at this instant.
  AccelAxis get dominantAxis {
    final ax = x.abs();
    final ay = y.abs();
    final az = z.abs();
    if (ax >= ay && ax >= az) return AccelAxis.x;
    if (ay >= az) return AccelAxis.y;
    return AccelAxis.z;
  }

  double component(AccelAxis axis) => switch (axis) {
    AccelAxis.x => x,
    AccelAxis.y => y,
    AccelAxis.z => z,
  };

  /// -1 or 1. Zero counts as positive; it never survives the threshold test.
  int signOf(AccelAxis axis) => component(axis) < 0 ? -1 : 1;

  @override
  String toString() =>
      'AccelSample(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)}, '
      '${z.toStringAsFixed(2)} @ ${t.inMilliseconds}ms)';
}
