// ---------------------------------------------------------------------------
// ANA EKRAN (KABUK / SHELL)
// ---------------------------------------------------------------------------
// Alt gezinme çubuğunu tutar. Sekmelerin kendisi router'daki
// StatefulShellRoute dallarıdır; bu kabuk yalnız gövdeyi ve çubuğu çizer.
// Dal bir kez açıldıktan sonra IndexedStack içinde kalır, bu yüzden sekme
// değişince kaydırma, liste ve yarım kalan giriş silinmez.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/uygulama_temasi.dart';
import '../../shared/widgets/asistan_ikonu.dart';

/// Alt gezinme çubuğuyla beş ana dalı gösteren kabuk.
class AnaSayfaEkrani extends StatelessWidget {
  const AnaSayfaEkrani({super.key, required this.navigationShell});

  /// Aktif dalın gövdesi. İndeks ve geçiş kararı bu nesnededir.
  final StatefulNavigationShell navigationShell;

  /// Aynı sekmeye tekrar basınca o dalın köküne dön (ör. forum listesi).
  /// Başka sekmeye basınca dalın kaldığı yer açılır.
  void _sekmeSec(int indeks) {
    navigationShell.goBranch(
      indeks,
      initialLocation: indeks == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: UygulamaTemasi.cizgi)),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _sekmeSec,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Ana Sayfa',
            ),
            NavigationDestination(
              icon: Icon(Icons.forum_outlined),
              selectedIcon: Icon(Icons.forum),
              label: 'Forum',
            ),
            NavigationDestination(
              icon: AsistanIkonu(isActive: false),
              selectedIcon: AsistanIkonu(isActive: true),
              label: 'AI Asistan',
            ),
            NavigationDestination(
              icon: Icon(Icons.restaurant_menu_outlined),
              selectedIcon: Icon(Icons.restaurant_menu),
              label: 'Beslenme',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
