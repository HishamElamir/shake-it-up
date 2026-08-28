import 'package:flutter_test/flutter_test.dart';
import 'package:shake_it_up/domain/random_source.dart';
import 'package:shake_it_up/domain/selection_engine.dart';

/// Hands back a fixed script of indices, so a test can state exactly what the
/// engine should do with them.
class ScriptedRandom implements RandomSource {
  ScriptedRandom(this.script);

  final List<int> script;
  int _next = 0;

  @override
  int nextInt(int max) {
    final value = script[_next++ % script.length];
    return value % max;
  }
}

void main() {
  final items = ['a', 'b', 'c', 'd'];

  group('pure random', () {
    test('returns the candidate the source points at', () {
      final engine = SelectionEngine(ScriptedRandom([2]));
      final outcome = engine.draw(
        candidates: items,
        mode: SelectionMode.pureRandom,
      );
      expect(outcome.winner, 'c');
    });

    test('may repeat the last winner — that is what independent means', () {
      final engine = SelectionEngine(ScriptedRandom([1]));
      final outcome = engine.draw(
        candidates: items,
        mode: SelectionMode.pureRandom,
        lastWinner: 'b',
      );
      expect(outcome.winner, 'b');
    });
  });

  group('no immediate repeat', () {
    test('never returns the last winner', () {
      final engine = SelectionEngine(DartRandomSource.seeded(7));
      var last = 'a';
      for (var i = 0; i < 500; i++) {
        final outcome = engine.draw(candidates: items, lastWinner: last);
        expect(outcome.winner, isNot(last));
        last = outcome.winner;
      }
    });

    test('a single candidate always wins, repeat or not', () {
      final engine = SelectionEngine(DartRandomSource.seeded(1));
      final outcome = engine.draw(candidates: ['only'], lastWinner: 'only');
      expect(outcome.winner, 'only');
    });

    test('draws freely when there is no previous winner', () {
      final engine = SelectionEngine(ScriptedRandom([0]));
      expect(engine.draw(candidates: items).winner, 'a');
    });
  });

  group('shuffle bag', () {
    test('shows every candidate once before repeating any', () {
      final engine = SelectionEngine(DartRandomSource.seeded(3));
      var bag = const BagState<String>.empty();
      final seen = <String>[];

      for (var i = 0; i < items.length; i++) {
        final outcome = engine.draw(
          candidates: items,
          mode: SelectionMode.shuffleBag,
          bag: bag,
        );
        bag = outcome.bag;
        seen.add(outcome.winner);
      }

      expect(seen.toSet(), items.toSet());
      expect(bag.remaining, isEmpty);
    });

    test('refills once exhausted and keeps going', () {
      final engine = SelectionEngine(DartRandomSource.seeded(11));
      var bag = const BagState<String>.empty();
      final seen = <String>[];

      for (var i = 0; i < items.length * 3; i++) {
        final outcome = engine.draw(
          candidates: items,
          mode: SelectionMode.shuffleBag,
          bag: bag,
        );
        bag = outcome.bag;
        seen.add(outcome.winner);
      }

      // Three complete cycles: each item exactly three times.
      for (final item in items) {
        expect(seen.where((entry) => entry == item), hasLength(3));
      }
    });

    test('never repeats across a refill boundary', () {
      final engine = SelectionEngine(DartRandomSource.seeded(5));
      var bag = const BagState<String>.empty();
      String? last;

      for (var i = 0; i < 200; i++) {
        final outcome = engine.draw(
          candidates: items,
          mode: SelectionMode.shuffleBag,
          lastWinner: last,
          bag: bag,
        );
        expect(outcome.winner, isNot(last));
        bag = outcome.bag;
        last = outcome.winner;
      }
    });

    test(
      'a new picture joins immediately instead of waiting out the cycle',
      () {
        final engine = SelectionEngine(DartRandomSource.seeded(2));
        var bag = const BagState<String>.empty();

        // Burn through most of a bag built from the original four.
        for (var i = 0; i < 3; i++) {
          bag = engine
              .draw(candidates: items, mode: SelectionMode.shuffleBag, bag: bag)
              .bag;
        }

        final grown = [...items, 'e'];
        final outcome = engine.draw(
          candidates: grown,
          mode: SelectionMode.shuffleBag,
          bag: bag,
        );

        // The stale bag is discarded, so the new candidate is in play at once.
        expect(bag.matches(grown), isFalse);
        expect([
          outcome.winner,
          ...outcome.bag.remaining,
        ], hasLength(grown.length));
        expect({outcome.winner, ...outcome.bag.remaining}, grown.toSet());
      },
    );

    test('a deleted picture cannot win', () {
      final engine = SelectionEngine(DartRandomSource.seeded(9));
      var bag = engine
          .draw(candidates: items, mode: SelectionMode.shuffleBag)
          .bag;

      final shrunk = ['a', 'b'];
      for (var i = 0; i < 50; i++) {
        final outcome = engine.draw(
          candidates: shrunk,
          mode: SelectionMode.shuffleBag,
          bag: bag,
        );
        expect(shrunk, contains(outcome.winner));
        bag = outcome.bag;
      }
    });
  });

  group('fairness', () {
    test('uniform within 3% over 100k draws', () {
      // 100k, not 10k: at 10k the 3% band is one standard deviation wide, so
      // the check would be noise. Seeded, so a pass is reproducible.
      const draws = 100000;
      const size = 10;
      final pool = List.generate(size, (index) => index);
      final engine = SelectionEngine(DartRandomSource.seeded(20260816));
      final counts = List.filled(size, 0);

      for (var i = 0; i < draws; i++) {
        counts[engine
                .draw(candidates: pool, mode: SelectionMode.pureRandom)
                .winner] +=
            1;
      }

      const expected = draws / size;
      for (var i = 0; i < size; i++) {
        expect(
          (counts[i] - expected).abs() / expected,
          lessThan(0.03),
          reason: 'item $i drew ${counts[i]} times, expected ~$expected',
        );
      }
    });

    test('the shuffle is a real shuffle, not a rotation', () {
      final engine = SelectionEngine(DartRandomSource.seeded(4));
      final firstOfCycle = <int>{};
      final pool = List.generate(6, (index) => index);

      for (var cycle = 0; cycle < 40; cycle++) {
        firstOfCycle.add(
          engine.draw(candidates: pool, mode: SelectionMode.shuffleBag).winner,
        );
      }
      expect(firstOfCycle.length, greaterThan(1));
    });
  });

  test('an empty candidate list is a programming error', () {
    final engine = SelectionEngine(DartRandomSource.seeded(1));
    expect(
      () => engine.draw(candidates: <String>[]),
      throwsA(isA<ArgumentError>()),
    );
  });
}
