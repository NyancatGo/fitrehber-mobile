// Ana sayfa içeriği — makale listesi ve kategori filtreleri burada.
// HomeScreen'den ayrıldı çünkü ileride API bağlantısı buraya eklenecek.

import 'package:flutter/material.dart';

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'FitRehber',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // Arama butonu
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {}, // Arama ekranı ilerleyen adımda eklenecek
          ),
        ],
      ),
      body: const Center(
        child: Text('Makaleler yükleniyor...'),
      ),
    );
  }
}
