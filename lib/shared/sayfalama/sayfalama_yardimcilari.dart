// ---------------------------------------------------------------------------
// SAYFALAMA (PAGINATION) YARDIMCILARI
// ---------------------------------------------------------------------------
// Sonsuz kaydırmalı listelerde, kullanıcı listenin sonuna yaklaştığında
// "bir sonraki sayfayı yükle" kararını verir ve sayfa yükleme hatasını
// kullanıcıya bildirir.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';

/// Sayfa yükleme başarısız olduğunda kullanıcıya gösterilen mesaj.
const sayfalamaYuklemeHataMesaji =
    'Daha fazla içerik yüklenemedi. Tekrar denemek için aşağı kaydırın.';

/// Kaydırma konumuna bakarak yeni sayfa yüklenip yüklenmeyeceğine karar verir.
///
/// Çok sık tetiklenmeyi önlemek için bir "gecikme" (beklemeSuresi) uygular.
class SayfalamaTetikleyici {
  SayfalamaTetikleyici({
    this.beklemeSuresi = const Duration(milliseconds: 200),
  });

  /// İki kontrol arasında geçmesi gereken en kısa süre.
  final Duration beklemeSuresi;

  /// En son kontrolün yapıldığı an (beklemeSuresi hesabı için).
  DateTime? _sonKontrol;

  /// Liste sonuna [esik] piksel kala `true` döner — yani yeni sayfa
  /// yüklenmelidir. Throttle süresi dolmadıysa `false` döner.
  bool yuklemeliMi(ScrollController controller, {double esik = 280}) {
    if (!controller.hasClients) return false;

    final now = DateTime.now();
    final sonKontrol = _sonKontrol;
    if (sonKontrol != null && now.difference(sonKontrol) < beklemeSuresi) {
      return false;
    }

    _sonKontrol = now;
    final konum = controller.position;
    return konum.pixels >= konum.maxScrollExtent - esik;
  }
}

/// Sayfalama hatası bildirir. [onRetry] verilirse "Tekrar Dene" aksiyonu ekler.
void sayfalamaYuklemeHatasiGoster(
  BuildContext context, {
  VoidCallback? onRetry,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: const Text(sayfalamaYuklemeHataMesaji),
      action: onRetry == null
          ? null
          : SnackBarAction(label: 'Tekrar Dene', onPressed: onRetry),
    ),
  );
}
