// Anasayfa ve forum ekranlarının paylaştığı içerik kartı parçaları.
// Daha önce ana_sayfa_icerigi.dart ve forum_ekrani.dart içinde birebir
// kopyalanmış olan widget'lar burada tek noktada toplanmıştır.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Tooltip(
        message: tooltip,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
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

  const IcerikEtiket({
    super.key,
    required this.text,
    required this.color,
    this.alpha = 0.2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// İçerik kartının 16:9 kapak görseli.
class IcerikKapakResmi extends StatelessWidget {
  final String url;

  const IcerikKapakResmi({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      imageBuilder: (context, imageProvider) => Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image(image: imageProvider, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
      placeholder: (context, url) => Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(color: const Color(0xFF2A2D37)),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
      errorWidget: (context, url, error) => const SizedBox.shrink(),
    );
  }
}

/// İlk yükleme sırasında gösterilen shimmer placeholder listesi.
class IcerikShimmerListe extends StatelessWidget {
  final double itemHeight;

  const IcerikShimmerListe({super.key, this.itemHeight = 100});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1A1D27),
      highlightColor: const Color(0xFF2A2D37),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) => Container(
          height: itemHeight,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(mesaj, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}
