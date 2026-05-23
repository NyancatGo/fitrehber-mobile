// ---------------------------------------------------------------------------
// UYGULAMA TEMASI
// ---------------------------------------------------------------------------
// Uygulamanın renk paleti, fontu ve genel görünümü burada tek noktadan
// tanımlanır. Tüm ekranlar bu temayı kullandığı için arayüz baştan sona
// tutarlı kalır; bir rengi değiştirmek istediğinizde sadece burayı düzenlersiniz.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Uygulamanın görsel kimliğini (renkler + tema) barındıran sınıf.
///
/// Örneği oluşturulmaz; renkler ve `koyuTema` doğrudan `UygulamaTemasi.anaRenk`
/// gibi statik olarak kullanılır.
class UygulamaTemasi {
  // --- Marka renkleri ------------------------------------------------------

  /// Marka rengi (turuncu). Butonlar, vurgular ve seçili öğelerde kullanılır.
  static const Color anaRenk = Color(0xFFF5A623);

  /// Uygulamanın en alttaki koyu arka plan rengi.
  static const Color arkaPlan = Color(0xFF0F1117);

  /// Kartların ve panellerin (yüzeylerin) arka plan rengi.
  static const Color yuzey = Color(0xFF1A1D27);

  /// Birincil metin rengi (beyaz) — başlıklar ve ana içerik için.
  static const Color anaMetin = Color(0xFFFFFFFF);

  /// İkincil metin rengi (gri) — açıklama ve yardımcı metinler için.
  static const Color ikincilMetin = Color(0xFF9E9E9E);

  /// Uygulamanın tamamında kullanılan koyu (dark) tema yapılandırması.
  static ThemeData koyuTema = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: arkaPlan,
    colorScheme: const ColorScheme.dark(
      primary: anaRenk,
      surface: yuzey,
      onPrimary: Colors.white,
      onSurface: anaMetin,
    ),
    // "Inter" yazı tipi Google Fonts üzerinden yüklenir; modern ve okunaklıdır.
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    appBarTheme: const AppBarTheme(
      backgroundColor: arkaPlan,
      elevation: 0,
      centerTitle: false,
    ),
  );
}
