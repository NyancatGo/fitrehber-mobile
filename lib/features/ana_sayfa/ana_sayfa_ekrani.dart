// ---------------------------------------------------------------------------
// ANA EKRAN (KABUK / SHELL)
// ---------------------------------------------------------------------------
// Uygulamanın iskeletidir: alttaki gezinme çubuğu (Bottom Navigation Bar) ile
// beş ana bölümü (Ana Sayfa, Forum, AI Asistan, Beslenme, Profil) barındırır.
// Kullanıcı bir sekmeye dokununca o sekmenin ekranı gösterilir.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import '../../shared/widgets/asistan_ikonu.dart';
import '../asistan/asistan_ekrani.dart';
import '../forum/forum_ekrani.dart';
import '../beslenme/beslenme_ekrani.dart';
import '../profil/profil_ekrani.dart';
import 'ana_sayfa_icerigi.dart';

/// Alt gezinme çubuğuyla ana bölümleri yöneten kabuk ekranı.
class AnaSayfaEkrani extends StatefulWidget {
  const AnaSayfaEkrani({super.key});

  @override
  State<AnaSayfaEkrani> createState() => _AnaSayfaEkraniDurumu();
}

class _AnaSayfaEkraniDurumu extends State<AnaSayfaEkrani> {
  // Aktif sekme indeksi
  int _secilenIndeks = 0;

  // Her sekmeye karşılık gelen ekranlar
  final List<Widget> _ekranlar = const [
    AnaSayfaIcerigi(),
    ForumEkrani(),
    AsistanEkrani(),
    BeslenmeEkrani(),
    ProfilEkrani(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Aktif sekmenin ekranını göster
      body: _ekranlar[_secilenIndeks],

      // Alt navigasyon çubuğu
      bottomNavigationBar: NavigationBar(
        selectedIndex: _secilenIndeks,
        onDestinationSelected: (indeks) {
          setState(() => _secilenIndeks = indeks);
        },
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
    );
  }
}
