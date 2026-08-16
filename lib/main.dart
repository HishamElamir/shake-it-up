import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/picture_repository.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final documents = await getApplicationDocumentsDirectory();
  final repository = PictureRepository(
    root: Directory(p.join(documents.path, 'pictures')),
  );
  await repository.init();

  runApp(
    ProviderScope(
      overrides: [pictureRepositoryProvider.overrideWithValue(repository)],
      child: const ShakeItUpApp(),
    ),
  );
}
