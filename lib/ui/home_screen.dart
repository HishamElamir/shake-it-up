import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/picture.dart';
import '../state/library_controller.dart';
import '../state/providers.dart';
import 'draw_screen.dart';
import 'picture_image.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _importing = false;

  Future<void> _import(Future<ImportReport> Function() run) async {
    setState(() => _importing = true);
    try {
      final report = await run();
      if (!mounted) return;
      if (report.failed > 0) {
        _say('Added ${report.added}. ${report.failed} could not be imported.');
      } else if (report.added > 0) {
        _say('Added ${report.added} picture${report.added == 1 ? '' : 's'}.');
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmRemove(Picture picture) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this picture?'),
        content: const Text(
          'It will be deleted from the app. '
          'The original in your photos is untouched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(libraryControllerProvider.notifier).remove(picture);
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryControllerProvider);
    final pictures = library.valueOrNull ?? const <Picture>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shake It Up'),
        bottom: _importing
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: switch (library) {
                AsyncLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
                AsyncError(:final error) => _Message(
                  icon: Icons.error_outline,
                  title: 'Could not open your library',
                  detail: '$error',
                ),
                _ =>
                  pictures.isEmpty
                      ? const _Message(
                          icon: Icons.photo_library_outlined,
                          title: 'No pictures yet',
                          detail:
                              'Add a few options, then shake your phone to '
                              'pick one of them at random.',
                        )
                      : _PictureGrid(
                          pictures: pictures,
                          onRemove: _confirmRemove,
                        ),
              },
            ),
            _BottomBar(
              pictures: pictures,
              busy: _importing,
              onGallery: () => _import(
                ref.read(libraryControllerProvider.notifier).addFromGallery,
              ),
              onCamera: () => _import(
                ref.read(libraryControllerProvider.notifier).addFromCamera,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PictureGrid extends StatelessWidget {
  const _PictureGrid({required this.pictures, required this.onRemove});

  final List<Picture> pictures;
  final ValueChanged<Picture> onRemove;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: pictures.length,
      itemBuilder: (context, index) {
        final picture = pictures[index];
        return Semantics(
          label: 'Picture ${index + 1} of ${pictures.length}',
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: PictureImage(picture: picture, cacheWidth: 320),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  tooltip: 'Remove',
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => onRemove(picture),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.pictures,
    required this.busy,
    required this.onGallery,
    required this.onCamera,
  });

  final List<Picture> pictures;
  final bool busy;
  final VoidCallback onGallery;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    final canDraw = pictures.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Photos'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onCamera,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Camera'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: canDraw
                ? () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const DrawScreen(),
                    ),
                  )
                : null,
            icon: const Icon(Icons.casino_outlined),
            label: Text(
              canDraw
                  ? 'Pick one of ${pictures.length}'
                  : 'Add pictures to start',
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
