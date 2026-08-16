import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/picture_repository.dart';
import '../domain/accel_sample.dart';
import '../domain/picture.dart';
import '../domain/random_source.dart';
import '../domain/selection_engine.dart';
import '../services/accelerometer.dart';
import '../services/photo_source.dart';
import 'draw_controller.dart';
import 'library_controller.dart';

/// Built in `main()` once the app documents directory is known, then injected
/// here. Reading it without that override is a programming error, not a
/// runtime condition to handle.
final pictureRepositoryProvider = Provider<PictureRepository>(
  (ref) => throw UnimplementedError('overridden in main()'),
);

final photoSourceProvider = Provider<PhotoSource>(
  (ref) => ImagePickerPhotoSource(),
);

final randomSourceProvider = Provider<RandomSource>(
  (ref) => DartRandomSource(),
);

final selectionEngineProvider = Provider<SelectionEngine>(
  (ref) => SelectionEngine(ref.watch(randomSourceProvider)),
);

final selectionModeProvider = StateProvider<SelectionMode>(
  (ref) => SelectionMode.noImmediateRepeat,
);

/// Shake sensitivity, as the acceleration threshold in m/s².
final shakeThresholdProvider = StateProvider<double>(
  (ref) => ShakeSensitivity.medium.threshold,
);

/// The raw sensor stream, as a plain provider so tests can swap in a fake
/// stream and drive the draw screen sample by sample.
final accelerometerStreamProvider = Provider<Stream<AccelSample>>(
  (ref) => accelerometerSamples(),
);

final libraryControllerProvider =
    AsyncNotifierProvider<LibraryController, List<Picture>>(
      LibraryController.new,
    );

/// Outlives the draw screen, so shuffle-bag progress and the last winner
/// survive a trip back to the library.
final selectionMemoryProvider = Provider<SelectionMemory>(
  (ref) => SelectionMemory(),
);

/// Auto-disposed: the draw screen always opens armed, never showing the
/// winner from last time.
final drawControllerProvider =
    NotifierProvider.autoDispose<DrawController, DrawState>(DrawController.new);

enum ShakeSensitivity {
  low(15.0, 'Low', 'Takes a firm shake'),
  medium(12.0, 'Medium', 'Balanced'),
  high(9.0, 'High', 'A flick is enough');

  const ShakeSensitivity(this.threshold, this.label, this.description);

  final double threshold;
  final String label;
  final String description;

  static ShakeSensitivity forThreshold(double threshold) => values.firstWhere(
    (value) => value.threshold == threshold,
    orElse: () => ShakeSensitivity.medium,
  );
}
