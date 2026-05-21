// Uygulamanın giriş noktası.
// ProviderScope: Riverpod state management için gerekli, tüm uygulamayı sarar.
// MaterialApp.router: go_router ile sayfa yönetimi yapar.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'FitRehber',
      theme: AppTheme.darkTheme, // Koyu tema
      routerConfig: router, // Sayfa yönlendirme
      debugShowCheckedModeBanner: false, // Debug bandını gizle
      // Turkce locale - showDatePicker ve diger material dialoglar icin
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [
        Locale('tr', 'TR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
