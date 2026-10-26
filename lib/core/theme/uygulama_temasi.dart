// FitRehber görsel dili: sıcak gri-siyah zemin, tek altın turuncu vurgu, Inter.
// Yüzeyler birbirine yakın tonlarda. Kart 16, düğme ve alan 12. Gölge ve gradyan yok.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Uygulamanın görsel kimliği. Örnek oluşturulmaz.
class UygulamaTemasi {
  /// Altın turuncu. Seçili öğe ve birincil eylem.
  static const Color anaRenk = Color(0xFFE08B3C);

  /// Turuncu düğmenin üstündeki koyu yazı.
  static const Color anaUstune = Color(0xFF1C140C);

  /// Sayfa zemini. Sıcak gri-siyah.
  static const Color arkaPlan = Color(0xFF171715);

  /// Geniş pencerede sütunun dışı. Bir adım daha koyu.
  static const Color tuval = Color(0xFF121210);

  /// Kart yüzeyi. Zeminden bir adım açık.
  static const Color yuzey = Color(0xFF232321);

  /// Ana yazı.
  static const Color anaMetin = Color(0xFFF4F3EF);

  /// İkincil yazı.
  static const Color ikincilMetin = Color(0xFFA3A39E);

  /// Ayırıcı. Karttan bir adım açık.
  static const Color cizgi = Color(0xFF3C3C3A);

  /// Beğeni, silme ve kalori aşımı. Turuncu düğmeyle karışmaz.
  static const Color hata = Color(0xFFDC5848);

  static const double yaricap = 16;

  /// Kart ve sayfa başlığı. Inter, varsayılan ağırlık 600.
  static TextStyle baslik({
    double? fontSize,
    FontWeight fontWeight = FontWeight.w600,
    double? height,
    double letterSpacing = -0.3,
    Color? color,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
      color: color ?? anaMetin,
    );
  }

  static ThemeData get koyuTema {
    final govde = GoogleFonts.interTextTheme(
      ThemeData.dark().textTheme,
    ).apply(bodyColor: anaMetin, displayColor: anaMetin);
    const kenar = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: cizgi),
    );
    final baslikStili = baslik(fontSize: 22, height: 1.15);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: arkaPlan,
      canvasColor: arkaPlan,
      colorScheme: const ColorScheme.dark(
        primary: anaRenk,
        onPrimary: anaUstune,
        secondary: anaRenk,
        onSecondary: anaUstune,
        surface: yuzey,
        onSurface: anaMetin,
        error: hata,
        onError: anaMetin,
        outline: cizgi,
        surfaceTint: Color(0x00000000),
      ),
      textTheme: govde.copyWith(
        headlineMedium: baslik(fontSize: 26, height: 1.1, letterSpacing: -0.4),
        titleLarge: baslikStili,
        titleMedium: baslik(fontSize: 18, height: 1.2),
        bodyLarge: govde.bodyLarge?.copyWith(
          fontSize: 16,
          height: 1.5,
          color: ikincilMetin,
        ),
        bodyMedium: govde.bodyMedium?.copyWith(
          fontSize: 14,
          height: 1.5,
          color: anaMetin,
        ),
        labelLarge: govde.labelLarge?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: arkaPlan,
        foregroundColor: anaMetin,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: baslikStili,
      ),
      cardTheme: const CardThemeData(
        color: yuzey,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(yaricap)),
          side: BorderSide(color: cizgi),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: yuzey,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: yuzey,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(color: cizgi, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: yuzey,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: const TextStyle(color: ikincilMetin),
        hintStyle: const TextStyle(color: ikincilMetin),
        prefixIconColor: ikincilMetin,
        suffixIconColor: ikincilMetin,
        border: kenar,
        enabledBorder: kenar,
        focusedBorder: kenar.copyWith(
          borderSide: const BorderSide(color: anaRenk, width: 1.4),
        ),
        errorBorder: kenar.copyWith(borderSide: const BorderSide(color: hata)),
        focusedErrorBorder: kenar.copyWith(
          borderSide: const BorderSide(color: hata, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: anaRenk,
          foregroundColor: anaUstune,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: anaRenk,
          foregroundColor: anaUstune,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: anaMetin,
          backgroundColor: yuzey,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: cizgi),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: anaRenk,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: arkaPlan,
        elevation: 0,
        height: 68,
        indicatorColor: anaRenk.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final secili = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: secili ? FontWeight.w600 : FontWeight.w500,
            color: secili ? anaRenk : ikincilMetin,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final secili = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: secili ? anaRenk : ikincilMetin,
          );
        }),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: anaRenk),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: yuzey,
        contentTextStyle: TextStyle(color: anaMetin, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        actionTextColor: anaRenk,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: cizgi),
        ),
      ),
      iconTheme: const IconThemeData(color: anaMetin),
    );
  }
}

/// Geniş pencerede uygulamayı ortada, telefon genişliğinde tutar.
class GenisEkranCercesi extends StatelessWidget {
  const GenisEkranCercesi({super.key, required this.child});

  final Widget child;

  static const double _kolon = 460;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.size.width <= _kolon + 32) return child;

    return ColoredBox(
      color: UygulamaTemasi.tuval,
      child: Center(
        child: MediaQuery(
          data: media.copyWith(size: Size(_kolon, media.size.height)),
          child: SizedBox(
            width: _kolon,
            height: media.size.height,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: UygulamaTemasi.arkaPlan,
                border: Border.symmetric(
                  vertical: BorderSide(color: UygulamaTemasi.cizgi),
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
