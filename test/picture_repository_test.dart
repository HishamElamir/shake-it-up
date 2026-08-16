import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shake_it_up/data/picture_repository.dart';
import 'package:shake_it_up/domain/picture.dart';

/// The smallest valid PNG, so the files under test are real images.
final pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAE'
  'hQGAhKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  late Directory temp;
  late Directory incoming;
  late Directory libraryRoot;
  late PictureRepository repository;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('shake_it_up_');
    incoming = await Directory(p.join(temp.path, 'incoming')).create();
    libraryRoot = Directory(p.join(temp.path, 'pictures'));
    repository = PictureRepository(root: libraryRoot);
    await repository.init();
  });

  tearDown(() async {
    if (temp.existsSync()) await temp.delete(recursive: true);
  });

  File source(String name) =>
      File(p.join(incoming.path, name))..writeAsBytesSync(pngBytes);

  Future<List<Picture>> addAll(List<String> names) async {
    final added = <Picture>[];
    for (final name in names) {
      added.add(await repository.add(source(name), existing: added));
    }
    return added;
  }

  group('adding', () {
    test('copies the file in and leaves the original alone', () async {
      final original = source('holiday.png');
      final picture = await repository.add(original, existing: const []);

      expect(repository.fileOf(picture).existsSync(), isTrue);
      expect(original.existsSync(), isTrue, reason: 'we copy, never move');
      expect(repository.fileOf(picture).readAsBytesSync(), equals(pngBytes));
    });

    test('stores a relative file name, never an absolute path', () async {
      final picture = await repository.add(source('a.png'), existing: const []);
      expect(p.isAbsolute(picture.fileName), isFalse);
      expect(picture.fileName, isNot(contains(libraryRoot.path)));
    });

    test('keeps a known extension and normalises an unknown one', () async {
      final png = await repository.add(source('a.PNG'), existing: const []);
      final odd = await repository.add(source('b.tiff'), existing: [png]);

      expect(p.extension(png.fileName), '.png');
      expect(p.extension(odd.fileName), '.jpg');
    });

    test('gives every picture a distinct file', () async {
      final pictures = await addAll(['a.png', 'b.png', 'c.png']);
      final names = pictures.map((picture) => picture.fileName).toSet();
      expect(names, hasLength(3));
    });
  });

  group('loading', () {
    test('survives a restart', () async {
      final added = await addAll(['a.png', 'b.png']);

      final reopened = PictureRepository(root: libraryRoot);
      final loaded = await reopened.load();

      expect(loaded.map((picture) => picture.id), added.map((p) => p.id));
    });

    test('drops entries whose file has gone missing', () async {
      final pictures = await addAll(['a.png', 'b.png']);
      repository.fileOf(pictures.first).deleteSync();

      final loaded = await repository.load();

      expect(loaded, hasLength(1));
      expect(loaded.single.id, pictures.last.id);
    });

    test('sweeps away files the index does not know about', () async {
      await addAll(['a.png']);
      final orphan = File(p.join(libraryRoot.path, 'stray.jpg'))
        ..writeAsBytesSync(pngBytes);

      await repository.load();

      expect(orphan.existsSync(), isFalse);
    });

    test('a corrupt index reads as an empty library, not a crash', () async {
      await addAll(['a.png']);
      File(p.join(libraryRoot.path, 'index.json')).writeAsStringSync('{oh no');

      final loaded = await repository.load();

      expect(loaded, isEmpty);
    });

    test('an empty library loads cleanly on first run', () async {
      final fresh = PictureRepository(
        root: Directory(p.join(temp.path, 'brand_new')),
      );
      expect(await fresh.load(), isEmpty);
    });
  });

  group('removing', () {
    test('deletes the file and forgets the entry', () async {
      final pictures = await addAll(['a.png', 'b.png']);
      final doomed = pictures.first;

      await repository.remove(doomed, existing: pictures);

      expect(repository.fileOf(doomed).existsSync(), isFalse);
      expect(await repository.load(), hasLength(1));
    });

    test('clear empties the library but keeps it usable', () async {
      await addAll(['a.png', 'b.png']);
      await repository.clear();

      expect(await repository.load(), isEmpty);
      expect(libraryRoot.existsSync(), isTrue);

      final picture = await repository.add(source('c.png'), existing: const []);
      expect(repository.fileOf(picture).existsSync(), isTrue);
    });
  });
}
