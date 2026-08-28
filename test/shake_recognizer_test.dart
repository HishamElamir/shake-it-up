import 'package:flutter_test/flutter_test.dart';
import 'package:shake_it_up/domain/accel_sample.dart';
import 'package:shake_it_up/domain/shake_recognizer.dart';

import 'support/traces.dart';

/// Replays a trace and returns the timestamp of every shake it fired.
List<Duration> fire(ShakeRecognizer recognizer, List<AccelSample> trace) => [
  for (final sample in trace)
    if (recognizer.add(sample)) sample.t,
];

void main() {
  group('recognises a real shake', () {
    test('a deliberate shake fires exactly once', () {
      final fired = fire(ShakeRecognizer(), shakeBurst());
      expect(fired, hasLength(1));
      expect(fired.single, lessThan(const Duration(milliseconds: 400)));
    });

    test('fires on high sensitivity for a gentler shake', () {
      final gentle = shakeBurst(amplitude: 10.5);
      expect(fire(ShakeRecognizer(), gentle), isEmpty);
      expect(
        fire(ShakeRecognizer(threshold: ShakeRecognizer.highThreshold), gentle),
        hasLength(1),
      );
    });

    test('low sensitivity needs a harder shake', () {
      final normal = shakeBurst(amplitude: 13);
      expect(fire(ShakeRecognizer(), normal), hasLength(1));
      expect(
        fire(ShakeRecognizer(threshold: ShakeRecognizer.lowThreshold), normal),
        isEmpty,
      );
    });
  });

  group('ignores everything that is not a shake', () {
    test('a phone set down hard does not fire', () {
      expect(fire(ShakeRecognizer(), setDown()), isEmpty);
    });

    test('walking does not fire', () {
      expect(fire(ShakeRecognizer(), walking()), isEmpty);
    });

    test('slow rocking does not fire — reversals fall outside the window', () {
      expect(fire(ShakeRecognizer(), slowRocking()), isEmpty);
    });

    test('a phone at rest does not fire', () {
      expect(
        fire(ShakeRecognizer(), idle(duration: const Duration(seconds: 5))),
        isEmpty,
      );
    });

    test('two separate jolts a second apart do not add up to a shake', () {
      final trace = [
        ...setDown(),
        ...idle(from: const Duration(milliseconds: 400)),
        ...setDown(from: const Duration(milliseconds: 1200)),
      ];
      expect(fire(ShakeRecognizer(), trace), isEmpty);
    });
  });

  group('cooldown', () {
    test('one continuous shake never fires twice inside the cooldown', () {
      final recognizer = ShakeRecognizer();
      final fired = fire(
        recognizer,
        shakeBurst(duration: const Duration(seconds: 5)),
      );

      expect(fired.length, greaterThan(1), reason: 'should keep drawing');
      for (var i = 1; i < fired.length; i++) {
        expect(
          fired[i] - fired[i - 1],
          greaterThanOrEqualTo(recognizer.cooldown),
          reason: 'draws must be at least a cooldown apart',
        );
      }
    });

    test('a five second shake yields four draws', () {
      // Derived, not guessed: one fire ~240 ms in, then one per 1200 ms
      // cooldown plus the ~240 ms it takes to re-accumulate three reversals.
      final fired = fire(
        ShakeRecognizer(),
        shakeBurst(duration: const Duration(seconds: 5)),
      );
      expect(fired, hasLength(4));
    });
  });

  group('robustness', () {
    test('reset clears motion history and the cooldown', () {
      final recognizer = ShakeRecognizer();
      expect(fire(recognizer, shakeBurst()), hasLength(1));

      // Without a reset the cooldown would swallow this second burst.
      recognizer.reset();
      final again = shakeBurst(from: const Duration(milliseconds: 400));
      expect(fire(recognizer, again), hasLength(1));
    });

    test('out-of-order timestamps are ignored, not crashed on', () {
      final recognizer = ShakeRecognizer();
      final scrambled = shakeBurst().reversed.toList();
      expect(() => fire(recognizer, scrambled), returnsNormally);
    });

    test('an empty stream fires nothing', () {
      expect(fire(ShakeRecognizer(), const []), isEmpty);
    });

    test('progress reports how close the user is to a draw', () {
      final recognizer = ShakeRecognizer();
      expect(recognizer.progress, 0);

      for (final sample in shakeBurst(
        duration: const Duration(milliseconds: 160),
      )) {
        recognizer.add(sample);
      }
      expect(recognizer.progress, greaterThan(0));
      expect(recognizer.progress, lessThan(1));
    });
  });
}
