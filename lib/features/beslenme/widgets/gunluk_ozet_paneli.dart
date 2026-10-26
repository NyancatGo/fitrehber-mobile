// ---------------------------------------------------------------------------
// GÜNLÜK ÖZET PANOSU
// ---------------------------------------------------------------------------
// Beslenme ekranının üst kısmındaki kompakt özet kartı. Kullanıcıya o günkü
// durumu tek bakışta gösterir: kalan kalori, alınan kalori ve protein /
// karbonhidrat / yağ için ince ilerleme barları.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';

import '../../../core/theme/uygulama_temasi.dart';
import '../../../shared/models/beslenme_model.dart';
import '../../../shared/utils/beslenme_hesaplayici.dart';

/// Günlük kalori ve makro besin durumunu özetleyen pano widget'ı.
class GunlukOzetPaneli extends StatelessWidget {
  final GunlukBeslenmeModel veri;
  final BeslenmeHedefleri hedefler;

  const GunlukOzetPaneli({
    super.key,
    required this.veri,
    required this.hedefler,
  });

  @override
  Widget build(BuildContext context) {
    // Hedef asilinca "kalan" 0'da takilmasin; asim miktarini kirmizi gosteririz.
    final fark = hedefler.kaloriHedef - veri.kaloriKcal;
    final asimVar = fark < 0;
    final gosterilenDeger = asimVar ? -fark : fark;
    const asimRengi = UygulamaTemasi.hata;
    final kaloriOran = hedefler.kaloriHedef > 0
        ? (veri.kaloriKcal / hedefler.kaloriHedef).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: UygulamaTemasi.yuzey,
        borderRadius: BorderRadius.circular(UygulamaTemasi.yaricap),
        border: Border.all(color: UygulamaTemasi.cizgi),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$gosterilenDeger',
                          style: UygulamaTemasi.baslik(
                            fontSize: 36,
                            height: 1.0,
                            color: asimVar
                                ? asimRengi
                                : UygulamaTemasi.anaMetin,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'kcal',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: asimVar
                                ? asimRengi
                                : UygulamaTemasi.ikincilMetin,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      asimVar ? 'Kalori Aşıldı' : 'Kalan Kalori',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: asimVar
                            ? asimRengi
                            : UygulamaTemasi.ikincilMetin,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _KaloriMetrik(
                    ikon: Icons.local_fire_department_rounded,
                    renk: UygulamaTemasi.anaRenk,
                    deger: '${veri.kaloriKcal}',
                    etiket: 'Alınan',
                  ),
                  const SizedBox(height: 8),
                  _KaloriMetrik(
                    ikon: Icons.flag_rounded,
                    renk: UygulamaTemasi.ikincilMetin,
                    deger: '${hedefler.kaloriHedef}',
                    etiket: 'Hedef',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: kaloriOran),
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              builder: (context, oran, _) {
                return LinearProgressIndicator(
                  minHeight: 7,
                  value: oran,
                  backgroundColor: UygulamaTemasi.cizgi,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    asimVar ? asimRengi : UygulamaTemasi.anaRenk,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          // --- Makro Barları (ince) ---
          Row(
            children: [
              _MiniMakroBar(
                etiket: 'Protein',
                deger: veri.proteinG,
                hedef: hedefler.proteinHedefG,
                renk: UygulamaTemasi.anaRenk,
              ),
              const SizedBox(width: 10),
              _MiniMakroBar(
                etiket: 'Karb',
                deger: veri.karbonhidratG,
                hedef: hedefler.karbonhidratHedefG,
                renk: const Color(0xFFC9844A),
              ),
              const SizedBox(width: 10),
              _MiniMakroBar(
                etiket: 'Yağ',
                deger: veri.yagG,
                hedef: hedefler.yagHedefG,
                renk: UygulamaTemasi.ikincilMetin,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KaloriMetrik extends StatelessWidget {
  final IconData ikon;
  final Color renk;
  final String deger;
  final String etiket;

  const _KaloriMetrik({
    required this.ikon,
    required this.renk,
    required this.deger,
    required this.etiket,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(ikon, color: renk, size: 14),
        const SizedBox(width: 4),
        Text(
          deger,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: UygulamaTemasi.anaMetin,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          etiket,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: UygulamaTemasi.ikincilMetin,
          ),
        ),
      ],
    );
  }
}

class _MiniMakroBar extends StatelessWidget {
  final String etiket;
  final double deger;
  final double hedef;
  final Color renk;

  const _MiniMakroBar({
    required this.etiket,
    required this.deger,
    required this.hedef,
    required this.renk,
  });

  @override
  Widget build(BuildContext context) {
    final asimVar = hedef > 0 && deger > hedef;
    final yuzde = hedef > 0 ? (deger / hedef).clamp(0.0, 1.0) : 0.0;
    // Makro hedefi asilinca bar ve sayac kirmiziya doner.
    const asimRengi = UygulamaTemasi.hata;
    final barRenk = asimVar ? asimRengi : renk;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                etiket,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: UygulamaTemasi.ikincilMetin,
                ),
              ),
              Text(
                '${deger.toStringAsFixed(0)}/${hedef.toStringAsFixed(0)}g',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: asimVar
                      ? asimRengi.withValues(alpha: 0.9)
                      : UygulamaTemasi.ikincilMetin,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Stack(
              children: [
                Container(height: 6, color: UygulamaTemasi.cizgi),
                FractionallySizedBox(
                  widthFactor: yuzde,
                  child: Container(height: 6, color: barRenk),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
