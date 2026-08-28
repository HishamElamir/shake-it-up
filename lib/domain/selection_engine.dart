import 'random_source.dart';

enum SelectionMode {
  /// Independent draws. Repeats are possible, and correct.
  pureRandom,

  /// Never returns the previous winner while there is an alternative.
  /// The default, because users read an immediate repeat as a bug.
  noImmediateRepeat,

  /// Draw without replacement: everyone once before anyone twice.
  shuffleBag;

  String get label => switch (this) {
    SelectionMode.pureRandom => 'Pure random',
    SelectionMode.noImmediateRepeat => 'No repeat in a row',
    SelectionMode.shuffleBag => 'Everyone once',
  };

  String get description => switch (this) {
    SelectionMode.pureRandom => 'Every draw is independent.',
    SelectionMode.noImmediateRepeat => 'Never the same picture twice in a row.',
    SelectionMode.shuffleBag =>
      'Shows every picture once before repeating any.',
  };
}

/// The remaining pool for [SelectionMode.shuffleBag].
///
/// [source] is the candidate list the bag was built from; when the candidates
/// change — a picture is added or deleted — the bag is stale and gets rebuilt,
/// so a new picture never has to wait out the current cycle.
class BagState<T> {
  const BagState({required this.remaining, required this.source});

  const BagState.empty() : remaining = const [], source = const [];

  final List<T> remaining;
  final List<T> source;

  bool matches(List<T> candidates) =>
      source.length == candidates.length &&
      source.toSet().containsAll(candidates);
}

class DrawOutcome<T> {
  const DrawOutcome({required this.winner, required this.bag});

  final T winner;

  /// Carry this back into the next [SelectionEngine.draw] call. Meaningful
  /// only in shuffle-bag mode; empty otherwise.
  final BagState<T> bag;
}

/// Picks one winner. Pure, and deterministic for a given [RandomSource].
class SelectionEngine {
  const SelectionEngine(this._random);

  final RandomSource _random;

  /// Throws [ArgumentError] on an empty candidate list — callers must block
  /// the draw before it gets this far.
  ///
  /// [bag] is null on the first draw, and on every draw in a mode that has no
  /// bag. It must stay nullable rather than defaulting to
  /// `const BagState.empty()`: inside a generic method that would infer
  /// `BagState<Never>`, which type-errors the moment a real candidate list
  /// reaches it.
  DrawOutcome<T> draw<T>({
    required List<T> candidates,
    SelectionMode mode = SelectionMode.noImmediateRepeat,
    T? lastWinner,
    BagState<T>? bag,
  }) {
    if (candidates.isEmpty) {
      throw ArgumentError.value(candidates, 'candidates', 'must not be empty');
    }

    switch (mode) {
      case SelectionMode.pureRandom:
        return DrawOutcome(winner: _pick(candidates), bag: BagState<T>.empty());

      case SelectionMode.noImmediateRepeat:
        final pool = candidates.length > 1 && lastWinner != null
            ? candidates.where((c) => c != lastWinner).toList()
            : candidates;
        // `pool` is only empty if every candidate equals lastWinner, which
        // duplicate-free candidate lists cannot produce — but be safe.
        return DrawOutcome(
          winner: _pick(pool.isEmpty ? candidates : pool),
          bag: BagState<T>.empty(),
        );

      case SelectionMode.shuffleBag:
        var remaining = bag != null && bag.matches(candidates)
            ? List<T>.of(bag.remaining)
            : <T>[];
        if (remaining.isEmpty) {
          remaining = _shuffled(candidates);
          // Don't let a refill hand back the same winner across the boundary.
          if (remaining.length > 1 && remaining.first == lastWinner) {
            final swapWith = 1 + _random.nextInt(remaining.length - 1);
            final head = remaining[0];
            remaining[0] = remaining[swapWith];
            remaining[swapWith] = head;
          }
        }
        final winner = remaining.removeAt(0);
        return DrawOutcome(
          winner: winner,
          bag: BagState(remaining: remaining, source: List<T>.of(candidates)),
        );
    }
  }

  T _pick<T>(List<T> from) => from[_random.nextInt(from.length)];

  /// Fisher–Yates, driven by the injected source so tests stay deterministic.
  List<T> _shuffled<T>(List<T> items) {
    final out = List<T>.of(items);
    for (var i = out.length - 1; i > 0; i--) {
      final j = _random.nextInt(i + 1);
      final swap = out[i];
      out[i] = out[j];
      out[j] = swap;
    }
    return out;
  }
}
