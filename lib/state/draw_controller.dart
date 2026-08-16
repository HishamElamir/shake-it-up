import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/picture.dart';
import '../domain/selection_engine.dart';
import 'providers.dart';

sealed class DrawState {
  const DrawState();
}

/// Waiting for a shake or a tap.
class DrawArmed extends DrawState {
  const DrawArmed();
}

/// Nothing to draw from.
class DrawBlocked extends DrawState {
  const DrawBlocked();
}

/// Suspense: cycling through pictures on the way to a winner that has
/// *already been chosen*. The animation reveals the result, it never decides it.
class DrawSpinning extends DrawState {
  const DrawSpinning(this.teaser);

  final Picture teaser;
}

class DrawRevealed extends DrawState {
  const DrawRevealed(this.winner);

  final Picture winner;
}

/// What the selection engine needs to remember between draws.
///
/// Deliberately outside the controller: the controller is scoped to the draw
/// screen and dies with it, but "who won last" and "what's left in the bag"
/// have to survive the user stepping back to add another picture.
class SelectionMemory {
  Picture? lastWinner;
  BagState<Picture> bag = const BagState<Picture>.empty();
}

/// Scoped to the draw screen: opening it always starts armed, and closing it
/// disposes the state along with any animation in flight.
class DrawController extends AutoDisposeNotifier<DrawState> {
  /// Decelerating frame delays, ~800 ms total.
  static const _spinFrames = <int>[45, 50, 58, 68, 80, 95, 112, 132, 160];

  Timer? _timer;
  Picture? _pending;

  @override
  DrawState build() {
    ref.onDispose(_cancelSpin);
    return const DrawArmed();
  }

  bool get isSpinning => state is DrawSpinning;

  /// Picks a winner and shows it. [animate] false goes straight to the reveal —
  /// that is the reduce-motion path, not a debug shortcut.
  void draw({required List<Picture> pictures, bool animate = true}) {
    if (isSpinning) return; // one draw at a time
    if (pictures.isEmpty) {
      state = const DrawBlocked();
      return;
    }

    final memory = ref.read(selectionMemoryProvider);
    final outcome = ref
        .read(selectionEngineProvider)
        .draw<Picture>(
          candidates: pictures,
          mode: ref.read(selectionModeProvider),
          lastWinner: memory.lastWinner,
          bag: memory.bag,
        );
    memory
      ..bag = outcome.bag
      ..lastWinner = outcome.winner;
    _pending = outcome.winner;

    if (!animate || pictures.length == 1) {
      _reveal();
      return;
    }
    _spin(pictures);
  }

  /// Tapping during the suspense jumps to the result already decided.
  void skip() {
    if (isSpinning) _reveal();
  }

  void _spin(List<Picture> pictures) {
    var frame = 0;
    var index = ref.read(randomSourceProvider).nextInt(pictures.length);

    void tick() {
      if (frame >= _spinFrames.length) {
        _reveal();
        return;
      }
      index = (index + 1) % pictures.length;
      state = DrawSpinning(pictures[index]);
      _timer = Timer(Duration(milliseconds: _spinFrames[frame++]), tick);
    }

    tick();
  }

  void _reveal() {
    _cancelSpin();
    final winner = _pending;
    if (winner != null) state = DrawRevealed(winner);
  }

  void _cancelSpin() {
    _timer?.cancel();
    _timer = null;
  }
}
