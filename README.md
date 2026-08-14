# Shake It Up

Shake your phone, let it pick for you.

Build a **deck** of images — lunch spots, team members, workout cards, gift ideas — open it, shake
the phone, and the app reveals one at random. Built for the moment you need to choose something and
would rather not.

**Status:** design phase. No code yet — the specification and architecture below come first.

## Design documents

| Document | What's in it |
|---|---|
| [`docs/SRS.md`](docs/SRS.md) | Software Requirements Specification — scope, user classes, 54 functional requirements, 31 non-functional requirements, use cases, data requirements, acceptance criteria, risks, traceability |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Technical design — layers and folder structure, shake-detection algorithm, selection engine, database schema, image pipeline, state machine, testing strategy, decision log (ADRs), milestones |

## The shape of it

- **Flutter**, one codebase, Android 8+ / iOS 14+.
- **Fully offline.** No accounts, no backend, no network permission. Photos never leave the device.
- **Shake detection** requires real oscillation — three direction reversals inside 700 ms — so
  setting the phone down doesn't trigger a draw. Sensitivity is user-tunable with a calibration
  screen.
- **Three selection modes:** pure random, no-immediate-repeat (default), and a shuffle bag that
  shows every item once before repeating.
- **Tap-to-draw is always available**, so the app works for anyone who can't shake the device.
- The two pieces that can actually be *wrong* — gesture recognition and randomness — are pure Dart
  with injected sensor, clock, and RNG, tested against recorded motion traces and a statistical
  uniformity check.

## Next step

Milestone **M0 — Scaffold** in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) §13: create the Flutter
project, folder structure, DI, router, theme, localisation plumbing, and a green CI pipeline.
