// Anasayfa ve forum ekranlarının paylaştığı içerik kartı parçaları.
// Daha önce ana_sayfa_icerigi.dart ve forum_ekrani.dart içinde birebir
// kopyalanmış olan widget'lar burada tek noktada toplanmıştır.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/theme/uygulama_temasi.dart';

/// Yatay filtre şeridindeki sade seçim kapsülü.
class SecimYongasi extends StatelessWidget {
  final String etiket;
  final bool secili;
  final VoidCallback onTap;

  const SecimYongasi({
    super.key,
    required this.etiket,
    required this.secili,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            decoration: ShapeDecoration(
              color: secili ? UygulamaTemasi.anaRenk : UygulamaTemasi.yuzey,
              shape: StadiumBorder(
                side: BorderSide(
                  color: secili ? UygulamaTemasi.anaRenk : UygulamaTemasi.cizgi,
                ),
              ),
            ),
            child: Text(
              etiket,
              style: TextStyle(
                color: secili
                    ? UygulamaTemasi.anaUstune
                    : UygulamaTemasi.ikincilMetin,
                fontSize: 13,
                fontWeight: secili ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// İçerik kartlarındaki beğen/kaydet gibi hızlı aksiyon butonu.
class HizliAksiyonButonu extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const HizliAksiyonButonu({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final aktif = color != UygulamaTemasi.ikincilMetin;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Tooltip(
        message: tooltip,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          height: 34,
          padding: EdgeInsets.symmetric(horizontal: label.isEmpty ? 9 : 11),
          decoration: BoxDecoration(
            color: aktif
                ? color.withValues(alpha: 0.12)
                : UygulamaTemasi.arkaPlan.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: aktif
                  ? color.withValues(alpha: 0.42)
                  : UygulamaTemasi.cizgi,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 17),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Kategori / tür rozeti. [alpha] arka plan tonunu belirler.
class IcerikEtiket extends StatelessWidget {
  final String text;
  final Color color;
  final double alpha;
  final bool dolu;
  final bool cizgili;

  const IcerikEtiket({
    super.key,
    required this.text,
    required this.color,
    this.alpha = 0.2,
    this.dolu = false,
    this.cizgili = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: dolu
            ? color
            : (cizgili
                  ? UygulamaTemasi.arkaPlan.withValues(alpha: 0.45)
                  : color.withValues(alpha: alpha)),
        borderRadius: BorderRadius.circular(999),
        border: cizgili ? Border.all(color: UygulamaTemasi.cizgi) : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: dolu ? UygulamaTemasi.anaUstune : color,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

/// İçerik kartının 16:9 kapak görseli.
/// Bellek ve kaydırma performansı için `memCacheWidth` sınırlandırılmıştır.
class IcerikKapakResmi extends StatelessWidget {
  final String url;

  const IcerikKapakResmi({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      memCacheWidth: 900,
      fadeInDuration: const Duration(milliseconds: 180),
      imageBuilder: (context, imageProvider) => ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(UygulamaTemasi.yaricap),
        ),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Image(
            image: imageProvider,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.low,
          ),
        ),
      ),
      placeholder: (context, url) => ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(UygulamaTemasi.yaricap),
        ),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: ColoredBox(
            color: UygulamaTemasi.arkaPlan,
            child: Center(
              child: Icon(
                Icons.image_outlined,
                color: UygulamaTemasi.ikincilMetin.withValues(alpha: 0.35),
                size: 28,
              ),
            ),
          ),
        ),
      ),
      errorWidget: (context, url, error) => const SizedBox.shrink(),
    );
  }
}

/// İlk yükleme sırasında gösterilen yapısal kart iskelet (shimmer) listesi.
class IcerikShimmerListe extends StatelessWidget {
  final double itemHeight;

  const IcerikShimmerListe({super.key, this.itemHeight = 148});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Shimmer.fromColors(
        baseColor: UygulamaTemasi.yuzey,
        highlightColor: UygulamaTemasi.cizgi,
        child: ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: 4,
          itemBuilder: (context, index) => Container(
            height: itemHeight,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: UygulamaTemasi.yuzey,
              borderRadius: BorderRadius.circular(UygulamaTemasi.yaricap),
              border: Border.all(color: UygulamaTemasi.cizgi),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 76,
                  height: 20,
                  decoration: BoxDecoration(
                    color: UygulamaTemasi.cizgi,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: 16,
                  decoration: BoxDecoration(
                    color: UygulamaTemasi.cizgi,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 210,
                  height: 14,
                  decoration: BoxDecoration(
                    color: UygulamaTemasi.cizgi,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Container(
                      width: 96,
                      height: 12,
                      decoration: BoxDecoration(
                        color: UygulamaTemasi.cizgi,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 48,
                      height: 26,
                      decoration: BoxDecoration(
                        color: UygulamaTemasi.cizgi,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hata durumunda gösterilen, tekrar deneme butonlu görünüm.
class HataGorunumu extends StatelessWidget {
  final String mesaj;
  final VoidCallback onRetry;

  const HataGorunumu({super.key, required this.mesaj, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: UygulamaTemasi.yuzey,
            borderRadius: BorderRadius.circular(UygulamaTemasi.yaricap),
            border: Border.all(color: UygulamaTemasi.cizgi),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: UygulamaTemasi.hata.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 30,
                  color: UygulamaTemasi.hata,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                mesaj,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: UygulamaTemasi.anaMetin,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Tekrar Dene'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Liste veya arama sonuçları boş olduğunda gösterilen ortak görünüm.
class BosDurumGorunumu extends StatelessWidget {
  final IconData ikon;
  final String mesaj;
  final String? altMesaj;
  final Widget? aksiyon;

  const BosDurumGorunumu({
    super.key,
    required this.ikon,
    required this.mesaj,
    this.altMesaj,
    this.aksiyon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: UygulamaTemasi.anaRenk.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: UygulamaTemasi.anaRenk.withValues(alpha: 0.28),
                ),
              ),
              child: Icon(ikon, size: 26, color: UygulamaTemasi.anaRenk),
            ),
            const SizedBox(height: 14),
            Text(
              mesaj,
              textAlign: TextAlign.center,
              style: UygulamaTemasi.baslik(fontSize: 16, height: 1.3),
            ),
            if (altMesaj != null) ...[
              const SizedBox(height: 6),
              Text(
                altMesaj!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: UygulamaTemasi.ikincilMetin,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
            if (aksiyon != null) ...[const SizedBox(height: 16), aksiyon!],
          ],
        ),
      ),
    );
  }
}
