// Uygulamanın renk paleti ve genel görünümü burada tanımlandı.
// Tüm ekranlarda aynı renk ve font kullanılır.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Ana renkler
  static const Color primary       = Color(0xFFF5A623); // Turuncu — marka rengi
  static const Color background    = Color(0xFF0F1117); // Koyu arka plan
  static const Color surface       = Color(0xFF1A1D27); // Kart/panel arka planı
  static const Color textPrimary   = Color(0xFFFFFFFF); // Beyaz metin
  static const Color textSecondary = Color(0xFF9E9E9E); // Gri metin

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      surface: surface,
      onPrimary: Colors.white,
      onSurface: textPrimary,
    ),
    // Inter fontu — Google Fonts'tan yüklenir
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      elevation: 0,
      centerTitle: false,
    ),
  );
}
