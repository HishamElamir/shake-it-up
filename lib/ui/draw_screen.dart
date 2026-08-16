import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/accel_sample.dart';
import '../domain/picture.dart';
import '../domain/selection_engine.dart';
import '../domain/shake_recognizer.dart';
import '../state/draw_controller.dart';
import '../state/providers.dart';
import 'picture_image.dart';

/// The point of the whole app: shake, get one picture back.
class DrawScreen extends ConsumerStatefulWidget {
  const DrawScreen({super.key});

  @override
  ConsumerState<DrawScreen> createState() => _DrawScreenState();
}

class _DrawScreenState extends ConsumerState<DrawScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  StreamSubscription<AccelSample>? _subscription;
  ShakeRecognizer _recognizer = ShakeRecognizer();
  late final AnimationController _hint;
  bool _sensorFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _hint = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _subscribe();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unsubscribe();
    _hint.dispose();
    super.dispose();
  }

  /// The sensor is a leased resource: nothing is listening while the app is
  /// in the background, and nothing is listening once this screen is gone.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _subscribe();
    } else {
      _unsubscribe();
    }
  }

  void _subscribe() {
    _unsubscribe();
    _recognizer = ShakeRecognizer(threshold: ref.read(shakeThresholdProvider));
    _subscription = ref
        .read(accelerometerStreamProvider)
        .listen(
          _onSample,
          onError: (Object _) {
            if (mounted) setState(() => _sensorFailed = true);
          },
          cancelOnError: true,
        );
  }

  void _unsubscribe() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _onSample(AccelSample sample) {
    if (!mounted) return;
    if (_recognizer.add(sample)) _draw();
  }

  void _draw() {
    final pictures =
        ref.read(libraryControllerProvider).valueOrNull ?? const <Picture>[];
    ref
        .read(drawControllerProvider.notifier)
        .draw(
          pictures: pictures,
          animate: !MediaQuery.disableAnimationsOf(context),
        );
  }

  Future<void> _openOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _OptionsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Changing sensitivity rebuilds the recogniser with the new threshold.
    ref.listen(shakeThresholdProvider, (_, _) => _subscribe());

    ref.listen<DrawState>(drawControllerProvider, (previous, next) {
      if (next is DrawRevealed && previous is! DrawRevealed) {
        HapticFeedback.mediumImpact();
        unawaited(
          SemanticsService.sendAnnouncement(
            View.of(context),
            'Picture selected',
            Directionality.of(context),
          ),
        );
      }
    });

    final state = ref.watch(drawControllerProvider);
    final pictures =
        ref.watch(libraryControllerProvider).valueOrNull ?? const <Picture>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick one'),
        actions: [
          IconButton(
            tooltip: 'Options',
            onPressed: _openOptions,
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => ref.read(drawControllerProvider.notifier).skip(),
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: switch (state) {
                    DrawBlocked() => const _Prompt(
                      icon: Icons.photo_library_outlined,
                      headline: 'Nothing to pick from',
                      detail: 'Go back and add a few pictures first.',
                    ),
                    DrawArmed() => _ArmedPrompt(
                      animation: _hint,
                      sensorFailed: _sensorFailed,
                      count: pictures.length,
                    ),
                    DrawSpinning(:final teaser) => _Stage(
                      picture: teaser,
                      dimmed: true,
                    ),
                    DrawRevealed(:final winner) => _Stage(picture: winner),
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: FilledButton.icon(
                  onPressed: pictures.isEmpty || state is DrawSpinning
                      ? null
                      : _draw,
                  icon: const Icon(Icons.casino_outlined),
                  label: Text(state is DrawRevealed ? 'Draw again' : 'Draw'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The picture on stage — mid-spin or as the winner.
class _Stage extends StatelessWidget {
  const _Stage({required this.picture, this.dimmed = false});

  final Picture picture;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedOpacity(
        opacity: dimmed ? 0.72 : 1,
        duration: const Duration(milliseconds: 120),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: PictureImage(picture: picture, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

class _ArmedPrompt extends StatelessWidget {
  const _ArmedPrompt({
    required this.animation,
    required this.sensorFailed,
    required this.count,
  });

  final Animation<double> animation;
  final bool sensorFailed;
  final int count;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final icon = Icon(
      sensorFailed ? Icons.touch_app_outlined : Icons.vibration,
      size: 64,
      color: Theme.of(context).colorScheme.primary,
    );

    return _Prompt(
      headline: sensorFailed ? 'Tap to draw' : 'Shake your phone',
      detail: sensorFailed
          ? 'This device has no usable motion sensor, so use the Draw button.'
          : 'Or use the Draw button. $count picture${count == 1 ? '' : 's'} in play.',
      child: reduceMotion || sensorFailed
          ? icon
          : AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                // A small back-and-forth tilt: the gesture, demonstrated.
                final wobble = Curves.easeInOut.transform(
                  (((animation.value * 2) % 1) - 0.5).abs() * 2,
                );
                return Transform.rotate(
                  angle: (wobble - 0.5) * 0.28,
                  child: child,
                );
              },
              child: icon,
            ),
    );
  }
}

class _Prompt extends StatelessWidget {
  const _Prompt({
    required this.headline,
    required this.detail,
    this.icon,
    this.child,
  });

  final String headline;
  final String detail;
  final IconData? icon;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          child ?? Icon(icon, size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 28),
          Text(headline, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              detail,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionsSheet extends ConsumerWidget {
  const _OptionsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mode = ref.watch(selectionModeProvider);
    final sensitivity = ShakeSensitivity.forThreshold(
      ref.watch(shakeThresholdProvider),
    );

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetHeading('How to pick', theme),
            RadioGroup<SelectionMode>(
              groupValue: mode,
              onChanged: (selected) {
                if (selected != null) {
                  ref.read(selectionModeProvider.notifier).state = selected;
                }
              },
              child: Column(
                children: [
                  for (final value in SelectionMode.values)
                    RadioListTile<SelectionMode>(
                      value: value,
                      title: Text(value.label),
                      subtitle: Text(value.description),
                    ),
                ],
              ),
            ),
            const Divider(height: 24),
            _SheetHeading('Shake sensitivity', theme),
            RadioGroup<ShakeSensitivity>(
              groupValue: sensitivity,
              onChanged: (selected) {
                if (selected != null) {
                  ref.read(shakeThresholdProvider.notifier).state =
                      selected.threshold;
                }
              },
              child: Column(
                children: [
                  for (final value in ShakeSensitivity.values)
                    RadioListTile<ShakeSensitivity>(
                      value: value,
                      title: Text(value.label),
                      subtitle: Text(value.description),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SheetHeading extends StatelessWidget {
  const _SheetHeading(this.text, this.theme);

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          letterSpacing: 1.2,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
