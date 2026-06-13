// ---------------------------------------------------------------------------
// GÜNLÜK ÖZET PANOSU
// ---------------------------------------------------------------------------
// Beslenme ekranının üst kısmındaki kompakt özet kartı. Kullanıcıya o günkü
// durumu tek bakışta gösterir: kalan kalori, alınan kalori ve protein /
// karbonhidrat / yağ için ince ilerleme barları.
// ---------------------------------------------------------------------------

import 'dart:math' as math;

import 'package:flutter/material.dart';

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
    const asimRengi = Color(0xFFEF4444);
    final oran = hedefler.kaloriHedef > 0
        ? veri.kaloriKcal / hedefler.kaloriHedef
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF1E2030), const Color(0xFF171923)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          // --- Kalori Özeti ---
          Row(
            children: [
              // Mini ilerleme halkası
              SizedBox(
                width: 72,
                height: 72,
                child: CustomPaint(
                  painter: _MiniHalkaPainter(
                    yuzde: oran.clamp(0.0, 1.0),
                    asimVar: asimVar,
                  ),
                  child: Center(
                    child: Text(
                      '${(oran * 100).clamp(0, 999).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: asimVar ? asimRengi : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // Kalori detayları
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$gosterilenDeger',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: asimVar ? asimRengi : Colors.white,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      asimVar ? 'Kalori Aşıldı' : 'Kalan Kalori',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: asimVar
                            ? asimRengi.withValues(alpha: 0.8)
                            : Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              // Alınan / Hedef
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _KaloriMetrik(
                    ikon: Icons.local_fire_department_rounded,
                    renk: const Color(0xFFF97316),
                    deger: '${veri.kaloriKcal}',
                    etiket: 'Alınan',
                  ),
                  const SizedBox(height: 8),
                  _KaloriMetrik(
                    ikon: Icons.flag_rounded,
                    renk: const Color(0xFF22C55E),
                    deger: '${hedefler.kaloriHedef}',
                    etiket: 'Hedef',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // --- Makro Barları (ince) ---
          Row(
            children: [
              _MiniMakroBar(
                etiket: 'Protein',
                deger: veri.proteinG,
                hedef: hedefler.proteinHedefG,
                renk: const Color(0xFF3B82F6),
              ),
              const SizedBox(width: 10),
              _MiniMakroBar(
                etiket: 'Karb',
                deger: veri.karbonhidratG,
                hedef: hedefler.karbonhidratHedefG,
                renk: const Color(0xFFF5A623),
              ),
              const SizedBox(width: 10),
              _MiniMakroBar(
                etiket: 'Yağ',
                deger: veri.yagG,
                hedef: hedefler.yagHedefG,
                renk: const Color(0xFFEF4444),
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
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          etiket,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.4),
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
    const asimRengi = Color(0xFFEF4444);
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
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              Text(
                '${deger.toStringAsFixed(0)}/${hedef.toStringAsFixed(0)}g',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: asimVar
                      ? asimRengi.withValues(alpha: 0.9)
                      : Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Stack(
              children: [
                Container(
                  height: 6,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
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

class _MiniHalkaPainter extends CustomPainter {
  final double yuzde;
  final bool asimVar;

  const _MiniHalkaPainter({required this.yuzde, this.asimVar = false});

  @override
  void paint(Canvas canvas, Size size) {
    final merkez = Offset(size.width / 2, size.height / 2);
    final yaricap = (size.width - 8) / 2;
    final rect = Rect.fromCircle(center: merkez, radius: yaricap);

    // Arka plan halkası — aşımda kırmızımsı zemin, kullanıcı tam doluyu hisseder.
    final bgPaint = Paint()
      ..color = asimVar
          ? const Color(0xFFEF4444).withValues(alpha: 0.18)
          : Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(merkez, yaricap, bgPaint);

    // İlerleme halkası — aşımda tam kırmızı, normalde turuncu→kırmızı gradient.
    if (yuzde > 0) {
      final fgPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;

      if (asimVar) {
        fgPaint.color = const Color(0xFFEF4444);
      } else {
        fgPaint.shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: 3 * math.pi / 2,
          colors: const [Color(0xFFF97316), Color(0xFFEF4444)],
          tileMode: TileMode.clamp,
        ).createShader(rect);
      }

      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * yuzde, false, fgPaint);
    }
  }

  @override
  bool shouldRepaint(_MiniHalkaPainter old) =>
      old.yuzde != yuzde || old.asimVar != asimVar;
}
