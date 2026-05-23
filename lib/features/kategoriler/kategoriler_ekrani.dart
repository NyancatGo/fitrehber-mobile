// ---------------------------------------------------------------------------
// KATEGORİLER EKRANI
// ---------------------------------------------------------------------------
// İçerik kategorilerinin listeleneceği ekran için ayrılmış basit iskelet.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';

/// İçerik kategorilerini gösteren ekran.
class KategorilerEkrani extends StatelessWidget {
  const KategorilerEkrani({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kategoriler')),
      body: const Center(child: Text('Kategoriler')),
    );
  }
}
