import 'package:flutter/material.dart';

import '../../core/theme/uygulama_temasi.dart';

/// Giriş ve kayıt ekranlarının küçük marka işareti.
class KimlikMarkasi extends StatelessWidget {
  const KimlikMarkasi({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: UygulamaTemasi.anaRenk.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.fitness_center,
          size: 22,
          color: UygulamaTemasi.anaRenk,
        ),
      ),
    );
  }
}
