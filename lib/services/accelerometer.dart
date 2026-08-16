import 'package:sensors_plus/sensors_plus.dart';

import '../domain/accel_sample.dart';

/// Adapts the platform sensor into the domain's [AccelSample].
///
/// `userAccelerometerEventStream` is already gravity-compensated by the
/// platform's sensor fusion, which is what makes behaviour consistent across
/// manufacturers — raw axes are not comparable between devices.
///
/// Timestamps come from a monotonic stopwatch started with the subscription,
/// so the recogniser never reads a wall clock that can jump.
Stream<AccelSample> accelerometerSamples() {
  final elapsed = Stopwatch()..start();
  return userAccelerometerEventStream(
    samplingPeriod: SensorInterval.gameInterval,
  ).map((event) => AccelSample(event.x, event.y, event.z, elapsed.elapsed));
}
