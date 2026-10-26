// ---------------------------------------------------------------------------
// SU TAKİBİ BÖLÜMÜ
// ---------------------------------------------------------------------------
// Beslenme ekranının en altındaki su takibi kartı. Günlük su hedefine göre
// ilerlemeyi gösterir ve web ile aynı hızlı su ekleme butonlarını sunar.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';

import '../../../core/theme/uygulama_temasi.dart';
import '../../../shared/utils/beslenme_hesaplayici.dart';

/// Günlük su tüketimini gösteren ve hızlı ekleme sağlayan bölüm widget'ı.
class SuTakipBolumu extends StatelessWidget {
  final int suMl;
  final BeslenmeHedefleri hedefler;
  final void Function(int ml) onEkle;
  final bool isLoading;

  const SuTakipBolumu({
    super.key,
    required this.suMl,
    required this.hedefler,
    required this.onEkle,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final yuzde = hedefler.suHedefMl > 0
        ? (suMl / hedefler.suHedefMl).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: UygulamaTemasi.yuzey,
        borderRadius: BorderRadius.circular(UygulamaTemasi.yaricap),
        border: Border.all(color: UygulamaTemasi.cizgi),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık satırı
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: UygulamaTemasi.anaRenk.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.water_drop_outlined,
                  color: UygulamaTemasi.anaRenk,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Su Tüketimi',
                  style: UygulamaTemasi.baslik(fontSize: 18, height: 1.15),
                ),
              ),
              Text(
                '$suMl / ${hedefler.suHedefMl} ml',
                style: TextStyle(
                  color: UygulamaTemasi.ikincilMetin,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // İlerleme çubuğu
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: yuzde),
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              builder: (context, oran, _) {
                return LinearProgressIndicator(
                  minHeight: 8,
                  value: oran,
                  backgroundColor: UygulamaTemasi.cizgi,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    UygulamaTemasi.anaRenk,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // Hızlı ekleme butonları
          Row(
            children: [
              Expanded(
                child: _SuButon(ml: 200, onEkle: onEkle, isLoading: isLoading),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SuButon(ml: 330, onEkle: onEkle, isLoading: isLoading),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SuButon(ml: 500, onEkle: onEkle, isLoading: isLoading),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Geri alma butonları
          Row(
            children: [
              Expanded(
                child: _SuButon(
                  ml: -200,
                  onEkle: onEkle,
                  isLoading: isLoading,
                  negatif: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuButon extends StatefulWidget {
  final int ml; // pozitif = ekle, negatif = cikar
  final void Function(int ml) onEkle;
  final bool isLoading;
  final bool negatif;

  const _SuButon({
    required this.ml,
    required this.onEkle,
    required this.isLoading,
    this.negatif = false,
  });

  @override
  State<_SuButon> createState() => _SuButonState();
}

class _SuButonState extends State<_SuButon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 0.1,
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _press() async {
    await _ctrl.forward();
    await _ctrl.reverse();
    widget.onEkle(widget.ml);
  }

  @override
  Widget build(BuildContext context) {
    final isari = widget.ml > 0;
    final etiket = isari ? '+${widget.ml} ml' : '${widget.ml} ml';
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: widget.isLoading ? null : _press,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // Pozitif: cyan -> blue gradient (mevcut)
            // Negatif: muted dark / cyan border (yumusak vurgu)
            color: widget.negatif
                ? UygulamaTemasi.yuzey
                : UygulamaTemasi.anaRenk,
            borderRadius: BorderRadius.circular(12),
            border: widget.negatif
                ? Border.all(color: UygulamaTemasi.cizgi)
                : null,
          ),
          child: Text(
            etiket,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: widget.negatif
                  ? UygulamaTemasi.anaMetin
                  : UygulamaTemasi.anaUstune,
            ),
          ),
        ),
      ),
    );
  }
}
