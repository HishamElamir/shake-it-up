import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/picture.dart';
import 'providers.dart';

typedef ImportReport = ({int added, int failed});

class LibraryController extends AsyncNotifier<List<Picture>> {
  @override
  Future<List<Picture>> build() => ref.read(pictureRepositoryProvider).load();

  Future<ImportReport> addFromGallery() async {
    final files = await ref.read(photoSourceProvider).pickFromGallery();
    return _addAll(files);
  }

  Future<ImportReport> addFromCamera() async {
    final file = await ref.read(photoSourceProvider).captureFromCamera();
    return _addAll([?file]);
  }

  /// Imports one at a time, publishing after each so thumbnails appear as they
  /// land. One bad file doesn't abort the batch — it is counted and reported.
  Future<ImportReport> _addAll(List<File> files) async {
    if (files.isEmpty) return (added: 0, failed: 0);

    final repository = ref.read(pictureRepositoryProvider);
    var current = List<Picture>.of(state.valueOrNull ?? const []);
    var added = 0;
    var failed = 0;

    for (final file in files) {
      try {
        final picture = await repository.add(file, existing: current);
        current = [...current, picture];
        added += 1;
        state = AsyncData(List<Picture>.of(current));
      } on FileSystemException {
        failed += 1;
      }
    }

    return (added: added, failed: failed);
  }

  Future<void> remove(Picture picture) async {
    final repository = ref.read(pictureRepositoryProvider);
    final current = List<Picture>.of(state.valueOrNull ?? const []);
    await repository.remove(picture, existing: current);
    state = AsyncData(
      current.where((entry) => entry.id != picture.id).toList(),
    );
  }
}
