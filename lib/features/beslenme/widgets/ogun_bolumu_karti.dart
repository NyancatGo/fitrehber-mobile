// ---------------------------------------------------------------------------
// ÖĞÜN BLOĞU KARTI
// ---------------------------------------------------------------------------
// Tek bir öğünü (sabah / öğle / akşam / atıştırmalık) temsil eden kart:
// öğün başlığı, o öğüne eklenmiş besinlerin listesi ve "+ Ekle" butonu.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/uygulama_temasi.dart';
import '../../../shared/models/beslenme_model.dart';
import '../providers/beslenme_provider.dart';
import 'besin_arama_paneli.dart';
import 'kayit_duzenle_sheet.dart';

/// Bir öğünü ve o öğüne eklenmiş besinleri gösteren kart widget'ı.
class OgunBolumuKarti extends ConsumerWidget {
  final String ogunTipi;
  final List<OgunKaydiModel> kayitlar;
  final bool isLoading;

  const OgunBolumuKarti({
    super.key,
    required this.ogunTipi,
    required this.kayitlar,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toplamKalori = kayitlar.fold<int>(
      0,
      (toplam, kayit) => toplam + kayit.kalori,
    );
    final toplamProtein = kayitlar.fold<double>(
      0,
      (toplam, kayit) => toplam + kayit.protein,
    );
    final toplamKarb = kayitlar.fold<double>(
      0,
      (toplam, kayit) => toplam + kayit.karbonhidrat,
    );
    final toplamYag = kayitlar.fold<double>(
      0,
      (toplam, kayit) => toplam + kayit.yag,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: UygulamaTemasi.yuzey,
        borderRadius: BorderRadius.circular(UygulamaTemasi.yaricap),
        border: Border.all(color: UygulamaTemasi.cizgi),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Başlık ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _ogunRengi(ogunTipi).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    _ogunIkonu(ogunTipi),
                    color: _ogunRengi(ogunTipi),
                    size: 19,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _ogunBasligi(ogunTipi),
                        style: UygulamaTemasi.baslik(
                          fontSize: 18,
                          height: 1.15,
                        ),
                      ),
                      if (kayitlar.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          'P ${toplamProtein.toStringAsFixed(0)}g • '
                          'K ${toplamKarb.toStringAsFixed(0)}g • '
                          'Y ${toplamYag.toStringAsFixed(0)}g',
                          style: const TextStyle(
                            color: UygulamaTemasi.ikincilMetin,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: UygulamaTemasi.arkaPlan,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: UygulamaTemasi.cizgi),
                  ),
                  child: Text(
                    '$toplamKalori kcal',
                    style: const TextStyle(
                      color: UygulamaTemasi.ikincilMetin,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- Kayıtlar ---
          if (kayitlar.isNotEmpty) ...[
            const Divider(height: 1, color: UygulamaTemasi.cizgi),
            for (var i = 0; i < kayitlar.length; i++) ...[
              if (i > 0)
                const Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: UygulamaTemasi.cizgi,
                ),
              _BesinKayitSatiri(kayit: kayitlar[i], isLoading: isLoading),
            ],
          ],

          // --- "+ Ekle" Butonu ---
          InkWell(
            onTap: isLoading
                ? null
                : () => showFoodSearchBottomSheet(context, ref, ogunTipi),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            child: Container(
              width: double.infinity,
              height: 44,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: UygulamaTemasi.cizgi)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.add_rounded,
                    color: UygulamaTemasi.anaRenk,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Ekle',
                    style: TextStyle(
                      color: UygulamaTemasi.anaRenk,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BesinKayitSatiri extends ConsumerWidget {
  final OgunKaydiModel kayit;
  final bool isLoading;

  const _BesinKayitSatiri({required this.kayit, required this.isLoading});

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: UygulamaTemasi.yuzey,
        title: const Text('Kaydı sil?'),
        content: Text('"${kayit.besinIsim}" kaydı silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Sil',
              style: TextStyle(color: UygulamaTemasi.hata),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(kayit.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: UygulamaTemasi.hata.withValues(alpha: 0.14),
        child: const Icon(Icons.delete_outline, color: UygulamaTemasi.hata),
      ),
      confirmDismiss: (_) async {
        if (isLoading) return false;
        return await _confirmDelete(context);
      },
      onDismissed: (_) {
        ref.read(beslenmeProvider.notifier).ogunSil(kayit.id);
      },
      child: InkWell(
        onTap: isLoading
            ? null
            : () => showKayitDuzenleSheet(context, ref, kayit),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kayit.besinIsim,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: UygulamaTemasi.anaMetin,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatMiktar(kayit.miktar)} ${kayit.miktarBirimi} • '
                      'P ${kayit.protein.toStringAsFixed(1)}g • '
                      'K ${kayit.karbonhidrat.toStringAsFixed(1)}g • '
                      'Y ${kayit.yag.toStringAsFixed(1)}g',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: UygulamaTemasi.ikincilMetin,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${kayit.kalori}',
                style: TextStyle(
                  color: UygulamaTemasi.anaMetin,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                ' kcal',
                style: TextStyle(
                  color: UygulamaTemasi.ikincilMetin,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right,
                color: UygulamaTemasi.ikincilMetin,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Helpers ---

String _ogunBasligi(String ogunTipi) {
  switch (ogunTipi) {
    case 'sabah':
      return 'Kahvaltı';
    case 'ogle':
      return 'Öğle Yemeği';
    case 'aksam':
      return 'Akşam Yemeği';
    case 'atistirmalik':
      return 'Atıştırmalık';
    default:
      return ogunTipi;
  }
}

IconData _ogunIkonu(String ogunTipi) {
  switch (ogunTipi) {
    case 'sabah':
      return Icons.wb_sunny_outlined;
    case 'ogle':
      return Icons.lunch_dining_outlined;
    case 'aksam':
      return Icons.dinner_dining_outlined;
    case 'atistirmalik':
      return Icons.local_cafe_outlined;
    default:
      return Icons.restaurant_outlined;
  }
}

Color _ogunRengi(String ogunTipi) {
  return UygulamaTemasi.anaRenk;
}

String _formatMiktar(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}
