# Shake It Up

Shake your phone, let it pick for you.

Add the pictures you're choosing between — lunch spots, teammates, workout cards, gift ideas —
then shake the phone and the app reveals one at random.

**Status:** the core loop is built and tested. Everything below runs; the design documents describe
where it goes next.

## Run it

```bash
flutter pub get
flutter run                 # a physical device — the simulator has no accelerometer
flutter test                # 50 tests, no device needed
flutter analyze --fatal-infos
```

Shaking needs real hardware. On a simulator, use the **Draw** button, which does exactly the same
thing.

## What's built

- **Add pictures** from the system photo picker (multi-select) or the camera. Each one is copied
  into app-private storage, downscaled to 2048 px, and stripped of EXIF metadata on the way in.
- **Shake to pick.** Recognition needs three direction reversals inside 700 ms, so setting the phone
  down doesn't trigger a draw. Sensitivity is switchable between low, medium, and high.
- **Three selection modes** — pure random, no-repeat-in-a-row (default), and a shuffle bag that
  shows every picture once before repeating.
- **Tap to draw**, always visible, so the app works without shaking at all.
- **A suspense reel** that cycles thumbnails and lands on the winner, with a haptic pulse — skipped
  automatically when the system reduce-motion setting is on.
- **It survives a restart**: pictures and their index are persisted, missing files are swept, and a
  corrupt index degrades to an empty library instead of a crash loop.

Not built yet: multiple decks, draw history, labels, undo, sharing, localisation. These are
specified in [`docs/SRS.md`](docs/SRS.md) and deliberately left for later.

## How it's put together

```
lib/
  domain/      pure Dart — no Flutter imports, no plugins
    shake_recognizer.dart   the gesture: reversal counting, windowing, cooldown
    selection_engine.dart   the randomness: three modes, injected RNG
  data/        picture_repository.dart — file copy-in, JSON index, orphan sweep
  services/    accelerometer + photo picker adapters, behind interfaces
  state/       Riverpod providers and the two controllers
  ui/          home (library grid) and draw (the point of the app)
```

The two components that can actually be *wrong* — gesture recognition and randomness — are pure
Dart with the sensor, clock, and RNG injected. That is why they can be tested on CI with no device:

| Test file | Covers |
|---|---|
| `shake_recognizer_test.dart` | Recorded-shape traces: a real shake fires once; setting the phone down, walking, slow rocking, and resting fire **zero** times; the cooldown holds under a continuous five-second shake |
| `selection_engine_test.dart` | Mode invariants, shuffle-bag exhaustion and refill, stale-bag rebuild when pictures change, uniformity within 3% over 100k draws |
| `picture_repository_test.dart` | Copy-not-move, relative paths, restart persistence, missing files, orphan sweep, corrupt index |
| `draw_screen_test.dart` | The whole loop through the real UI with a fake sensor stream, including that no accelerometer listener outlives the screen |
| `home_screen_test.dart` | Import from photos and camera, cancelling, removing |

## Design documents

| Document | What's in it |
|---|---|
| [`docs/SRS.md`](docs/SRS.md) | Requirements — 54 functional, 31 non-functional, use cases, acceptance criteria, risks |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Technical design — layers, shake algorithm, selection engine, storage, testing strategy, ADRs, milestones |

Where the built code deliberately differs from the full design, it is noted in
[`docs/ARCHITECTURE.md` §14](docs/ARCHITECTURE.md).

## Privacy

No network permission, no analytics, no accounts. Pictures are copied into app-private storage and
never leave the device.
