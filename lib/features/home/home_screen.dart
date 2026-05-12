// Ana ekran — Bottom Navigation Bar ile tüm bölümleri barındırır.
// Seçilen sekmeye göre ilgili ekran gösterilir.

import 'package:flutter/material.dart';
import '../categories/categories_screen.dart';
import '../forum/forum_screen.dart';
import '../profile/profile_screen.dart';
import 'home_content.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Aktif sekme indeksi
  int _secilenIndeks = 0;

  // Her sekmeye karşılık gelen ekranlar
  final List<Widget> _ekranlar = const [
    HomeContent(),      // Ana sayfa içeriği
    CategoriesScreen(), // Kategoriler
    ForumScreen(),      // Forum
    ProfileScreen(),    // Profil
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
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Kategoriler',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum),
            label: 'Forum',
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
