import 'dart:math' as math;

/// The app's only source of randomness, behind an interface so tests can seed
/// it and assert exact outcomes.
abstract class RandomSource {
  int nextInt(int max);
}

class DartRandomSource implements RandomSource {
  DartRandomSource([math.Random? random]) : _random = random ?? math.Random();

  /// Seeded, for deterministic tests.
  DartRandomSource.seeded(int seed) : _random = math.Random(seed);

  final math.Random _random;

  @override
  int nextInt(int max) => _random.nextInt(max);
}
