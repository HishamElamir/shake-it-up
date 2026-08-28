import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shake_it_up/data/picture_repository.dart';
import 'package:shake_it_up/services/photo_source.dart';
import 'package:shake_it_up/state/providers.dart';
import 'package:shake_it_up/ui/home_screen.dart';

final pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAE'
  'hQGAhKmMIQAAAABJRU5ErkJggg==',
);

class FakePhotoSource implements PhotoSource {
  FakePhotoSource({this.gallery = const [], this.camera});

  final List<File> gallery;
  final File? camera;

  @override
  Future<List<File>> pickFromGallery() async => gallery;

  @override
  Future<File?> captureFromCamera() async => camera;
}

void main() {
  late Directory temp;
  late Directory incoming;
  late PictureRepository repository;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('shake_it_up_home_');
    incoming = await Directory(p.join(temp.path, 'incoming')).create();
    repository = PictureRepository(
      root: Directory(p.join(temp.path, 'pictures')),
    );
    await repository.init();
  });

  tearDown(() async {
    if (temp.existsSync()) await temp.delete(recursive: true);
  });

  File source(String name) =>
      File(p.join(incoming.path, name))..writeAsBytesSync(pngBytes);

  Future<void> pumpHome(WidgetTester tester, PhotoSource photos) async {
    final container = ProviderContainer(
      overrides: [
        pictureRepositoryProvider.overrideWithValue(repository),
        photoSourceProvider.overrideWithValue(photos),
      ],
    );
    addTearDown(container.dispose);

    await tester.runAsync(
      () => container.read(libraryControllerProvider.future),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();
  }

  /// Taps something that kicks off real file I/O.
  ///
  /// The tap happens inside `runAsync` so the whole import chain runs on the
  /// real event loop; a tap in the ordinary test zone would suspend on the
  /// first `File.copy` and never resume.
  Future<void> tapAndSettleIo(WidgetTester tester, Finder target) async {
    await tester.runAsync(() async {
      await tester.tap(target);
      await Future<void>.delayed(const Duration(milliseconds: 250));
    });
    await tester.pump();
  }

  /// Alternates real-event-loop progress with pumps, for a chain that starts
  /// in the test zone (a dialog result) and then does real I/O.
  Future<void> settleIo(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
  }

  testWidgets('an empty library explains itself and blocks drawing', (
    tester,
  ) async {
    await pumpHome(tester, FakePhotoSource());

    expect(find.text('No pictures yet'), findsOneWidget);

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull, reason: 'nothing to pick from yet');
    expect(find.text('Add pictures to start'), findsOneWidget);
  });

  testWidgets('picking from photos fills the grid', (tester) async {
    await pumpHome(
      tester,
      FakePhotoSource(gallery: [source('a.png'), source('b.png')]),
    );

    await tapAndSettleIo(tester, find.text('Photos'));

    expect(find.text('Pick one of 2'), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);
    expect(await tester.runAsync(repository.load), hasLength(2));
  });

  testWidgets('the camera adds one picture', (tester) async {
    await pumpHome(tester, FakePhotoSource(camera: source('shot.png')));

    await tapAndSettleIo(tester, find.text('Camera'));

    expect(find.text('Pick one of 1'), findsOneWidget);
  });

  testWidgets('cancelling the picker changes nothing', (tester) async {
    await pumpHome(tester, FakePhotoSource());

    await tapAndSettleIo(tester, find.text('Photos'));

    expect(find.text('No pictures yet'), findsOneWidget);
  });

  testWidgets('removing a picture asks first, then deletes it', (tester) async {
    await pumpHome(
      tester,
      FakePhotoSource(gallery: [source('a.png'), source('b.png')]),
    );
    await tapAndSettleIo(tester, find.text('Photos'));

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
    expect(find.text('Remove this picture?'), findsOneWidget);

    // The dialog's pop runs on the fake clock, so settle that first, then let
    // the delete it triggers finish on the real one.
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    await settleIo(tester);

    expect(find.text('Pick one of 1'), findsOneWidget);
    expect(await tester.runAsync(repository.load), hasLength(1));
  });
}
