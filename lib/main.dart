// Uygulamanın giriş noktası.
// ProviderScope: Riverpod state management için gerekli, tüm uygulamayı sarar.
// MaterialApp.router: go_router ile sayfa yönetimi yapar.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FitRehber',
      theme: AppTheme.darkTheme,       // Koyu tema
      routerConfig: appRouter,          // Sayfa yönlendirme
      debugShowCheckedModeBanner: false, // Debug bandını gizle
    );
  }
}
