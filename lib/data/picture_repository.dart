import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/picture.dart';

/// Owns the image files and the small JSON index that describes them.
///
/// Two rules from the design carry through to the code:
///
///  * **Copy, never reference.** A picked photo's URI can be revoked or the
///    photo deleted at any moment. Everything here lives in app-private
///    storage, owned by this app.
///  * **File first, index second.** A crash mid-write leaves an orphan file,
///    never an index entry pointing at nothing — the far friendlier failure.
///    [load] sweeps orphans away on the next start.
///
/// [root] is injected rather than looked up, so the whole class is testable
/// against a temp directory with no plugins involved.
class PictureRepository {
  PictureRepository({required this.root});

  final Directory root;

  static const _indexFileName = 'index.json';
  static const _indexVersion = 1;

  File get _indexFile => File(p.join(root.path, _indexFileName));

  File fileOf(Picture picture) => File(p.join(root.path, picture.fileName));

  Future<void> init() async {
    if (!root.existsSync()) {
      await root.create(recursive: true);
    }
  }

  /// Reads the index, drops entries whose file has gone missing, and deletes
  /// image files the index doesn't know about.
  Future<List<Picture>> load() async {
    await init();

    var pictures = await _readIndex();

    final present = <Picture>[];
    var indexChanged = false;
    for (final picture in pictures) {
      if (fileOf(picture).existsSync()) {
        present.add(picture);
      } else {
        indexChanged = true;
      }
    }
    pictures = present;

    if (indexChanged) await _writeIndex(pictures);
    await _sweepOrphans(pictures);

    return pictures;
  }

  /// Copies [source] into the library and returns the new entry.
  ///
  /// The caller keeps the returned list; this method does not hold state.
  Future<Picture> add(File source, {required List<Picture> existing}) async {
    await init();

    final id = _newId();
    final extension = _safeExtension(source.path);
    final picture = Picture(
      id: id,
      fileName: '$id$extension',
      addedAt: DateTime.now().toUtc(),
    );

    await source.copy(fileOf(picture).path);
    await _writeIndex([...existing, picture]);

    return picture;
  }

  /// Removes the entry from the index first, then the file. In that order a
  /// failed delete leaves an orphan for the sweep, not a broken thumbnail.
  Future<void> remove(
    Picture picture, {
    required List<Picture> existing,
  }) async {
    await _writeIndex(
      existing.where((entry) => entry.id != picture.id).toList(),
    );
    final file = fileOf(picture);
    if (file.existsSync()) await file.delete();
  }

  Future<void> clear() async {
    if (root.existsSync()) await root.delete(recursive: true);
    await init();
  }

  Future<List<Picture>> _readIndex() async {
    if (!_indexFile.existsSync()) return const [];
    try {
      final raw = jsonDecode(await _indexFile.readAsString());
      if (raw is! Map<String, dynamic>) return const [];
      if (raw['version'] != _indexVersion) return const [];
      final entries = raw['pictures'];
      if (entries is! List) return const [];
      return entries
          .whereType<Map<String, dynamic>>()
          .map(Picture.fromJson)
          .toList();
    } on FormatException {
      // A truncated index is recoverable: the sweep will re-orphan the files
      // and the user sees an empty library rather than a crash loop.
      return const [];
    }
  }

  Future<void> _writeIndex(List<Picture> pictures) async {
    final payload = jsonEncode({
      'version': _indexVersion,
      'pictures': pictures.map((entry) => entry.toJson()).toList(),
    });
    // Write to a temp file and rename, so an interrupted write can't truncate
    // the existing index.
    final temp = File('${_indexFile.path}.tmp');
    await temp.writeAsString(payload, flush: true);
    await temp.rename(_indexFile.path);
  }

  Future<void> _sweepOrphans(List<Picture> known) async {
    final keep = {
      for (final picture in known) picture.fileName,
      _indexFileName,
    };
    await for (final entity in root.list()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (keep.contains(name)) continue;
      try {
        await entity.delete();
      } on FileSystemException {
        // Nothing to do about it; it will be retried on the next start.
      }
    }
  }

  static const _extensions = {'.jpg', '.jpeg', '.png', '.webp', '.heic'};

  String _safeExtension(String path) {
    final extension = p.extension(path).toLowerCase();
    return _extensions.contains(extension) ? extension : '.jpg';
  }

  var _counter = 0;

  String _newId() {
    // Monotonic and collision-free within a run without pulling in a uuid
    // dependency for what is a file name.
    _counter += 1;
    return '${DateTime.now().microsecondsSinceEpoch}_$_counter';
  }
}
