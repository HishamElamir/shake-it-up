import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/picture.dart';
import '../state/providers.dart';

/// Renders a picture from app-private storage.
///
/// A file that has gone missing shows a placeholder rather than throwing —
/// the library survives a restored backup or an out-of-band delete.
class PictureImage extends ConsumerWidget {
  const PictureImage({
    required this.picture,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    super.key,
  });

  final Picture picture;
  final BoxFit fit;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref.watch(pictureRepositoryProvider).fileOf(picture);
    return Image.file(
      file,
      fit: fit,
      cacheWidth: cacheWidth,
      // Keeps the previous frame on screen while the next decodes, which is
      // what stops the draw animation from flickering white between frames.
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.broken_image_outlined,
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}
