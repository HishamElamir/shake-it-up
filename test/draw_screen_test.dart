import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shake_it_up/data/picture_repository.dart';
import 'package:shake_it_up/domain/accel_sample.dart';
import 'package:shake_it_up/domain/picture.dart';
import 'package:shake_it_up/domain/random_source.dart';
import 'package:shake_it_up/state/draw_controller.dart';
import 'package:shake_it_up/state/providers.dart';
import 'package:shake_it_up/ui/draw_screen.dart';

import 'support/traces.dart';

final pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAE'
  'hQGAhKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  late Directory temp;
  late PictureRepository repository;
  late List<Picture> pictures;
  late StreamController<AccelSample> sensor;

  // setUp runs outside the fake-async zone of testWidgets, so real file I/O
  // is safe here. Inside a test body it would hang forever — which is why the
  // library is loaded through tester.runAsync below.
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('shake_it_up_ui_');
    repository = PictureRepository(
      root: Directory(p.join(temp.path, 'pictures')),
    );
    await repository.init();

    final incoming = await Directory(p.join(temp.path, 'incoming')).create();
    final added = <Picture>[];
    for (final name in ['a.png', 'b.png', 'c.png']) {
      final file = File(p.join(incoming.path, name))
        ..writeAsBytesSync(pngBytes);
      added.add(await repository.add(file, existing: added));
    }
    pictures = added;

    sensor = StreamController<AccelSample>.broadcast();
  });

  tearDown(() async {
    await sensor.close();
    if (temp.existsSync()) await temp.delete(recursive: true);
  });

  Future<ProviderContainer> pumpDrawScreen(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        pictureRepositoryProvider.overrideWithValue(repository),
        accelerometerStreamProvider.overrideWithValue(sensor.stream),
        randomSourceProvider.overrideWithValue(DartRandomSource.seeded(42)),
      ],
    );
    addTearDown(container.dispose);

    // Loading touches the real file system, so it has to run in the real async
    // zone; awaiting it directly in a test body would never complete.
    await tester.runAsync(
      () => container.read(libraryControllerProvider.future),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DrawScreen()),
      ),
    );
    await tester.pump();
    return container;
  }

  /// Replays a trace into the screen the way the sensor would.
  Future<void> feed(WidgetTester tester, List<AccelSample> trace) async {
    for (final sample in trace) {
      sensor.add(sample);
      await tester.pump();
    }
  }

  /// Runs out the suspense animation.
  Future<void> settleSpin(WidgetTester tester) async {
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('arms and asks for a shake', (tester) async {
    await pumpDrawScreen(tester);

    expect(find.text('Shake your phone'), findsOneWidget);
    expect(
      find.text('Draw'),
      findsOneWidget,
      reason: 'tap path is always there',
    );
  });

  testWidgets('a shake picks a winner', (tester) async {
    final container = await pumpDrawScreen(tester);

    await feed(tester, shakeBurst());
    await settleSpin(tester);

    final state = container.read(drawControllerProvider);
    expect(state, isA<DrawRevealed>());
    expect(find.text('Draw again'), findsOneWidget);

    expect(pictures, contains((state as DrawRevealed).winner));
  });

  testWidgets('setting the phone down does not pick anything', (tester) async {
    final container = await pumpDrawScreen(tester);

    await feed(tester, setDown());
    await settleSpin(tester);

    expect(container.read(drawControllerProvider), isA<DrawArmed>());
    expect(find.text('Shake your phone'), findsOneWidget);
  });

  testWidgets('walking around does not pick anything', (tester) async {
    final container = await pumpDrawScreen(tester);

    await feed(tester, walking(duration: const Duration(seconds: 2)));
    await settleSpin(tester);

    expect(container.read(drawControllerProvider), isA<DrawArmed>());
  });

  testWidgets('the Draw button works without any shake', (tester) async {
    final container = await pumpDrawScreen(tester);

    await tester.tap(find.text('Draw'));
    await settleSpin(tester);

    expect(container.read(drawControllerProvider), isA<DrawRevealed>());
  });

  testWidgets('drawing again after a reveal picks again', (tester) async {
    final container = await pumpDrawScreen(tester);

    await tester.tap(find.text('Draw'));
    await settleSpin(tester);
    final first =
        (container.read(drawControllerProvider) as DrawRevealed).winner;

    await tester.tap(find.text('Draw again'));
    await settleSpin(tester);
    final second =
        (container.read(drawControllerProvider) as DrawRevealed).winner;

    // Default mode is no-immediate-repeat, so a second draw must differ.
    expect(second, isNot(first));
  });

  testWidgets('releases the sensor when the screen goes away', (tester) async {
    await pumpDrawScreen(tester);
    expect(sensor.hasListener, isTrue);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();

    expect(
      sensor.hasListener,
      isFalse,
      reason: 'no accelerometer listener may outlive the draw screen',
    );
  });
}
