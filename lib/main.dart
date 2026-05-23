// Uygulamanın giriş noktası.
// ProviderScope: Riverpod state management için gerekli, tüm uygulamayı sarar.
// MaterialApp.router: go_router ile sayfa yönetimi yapar.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/uygulama_yonlendirici.dart';
import 'core/theme/uygulama_temasi.dart';

void main() {
  runApp(const ProviderScope(child: FitRehberUygulamasi()));
}

class FitRehberUygulamasi extends ConsumerWidget {
  const FitRehberUygulamasi({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(uygulamaYonlendiriciProvider);

    return MaterialApp.router(
      title: 'FitRehber',
      theme: UygulamaTemasi.koyuTema, // Koyu tema
      routerConfig: router, // Sayfa yönlendirme
      debugShowCheckedModeBanner: false, // Debug bandını gizle
      // Turkce locale - showDatePicker ve diger material dialoglar icin
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
