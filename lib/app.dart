import 'package:flutter/material.dart';

import 'ui/home_screen.dart';

class ShakeItUpApp extends StatelessWidget {
  const ShakeItUpApp({super.key});

  static const _seed = Color(0xFF0B6E77);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shake It Up',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: const HomeScreen(),
    );
  }

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
