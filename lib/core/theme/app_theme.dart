import 'package:flutter/material.dart';

/// Tema aplikasi. Fokus: tombol besar & kontras tinggi agar mudah dioperasikan
/// pembina di lapangan (dokumen desain bagian 5.1).
class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF1E6F5C));
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
