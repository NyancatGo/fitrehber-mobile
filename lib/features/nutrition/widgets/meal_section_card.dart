import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/beslenme_model.dart';
import '../providers/nutrition_provider.dart';
import 'food_search_sheet.dart';

/// FatSecret tarzı öğün bloğu. Başlık + eklenen besinlerin listesi + "+ Ekle" butonu.
class MealSectionCard extends ConsumerWidget {
  final String ogunTipi;
  final List<OgunKaydiModel> kayitlar;
  final bool isLoading;

  const MealSectionCard({
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

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Başlık ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _ogunRengi(ogunTipi).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _ogunIkonu(ogunTipi),
                    color: _ogunRengi(ogunTipi),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _ogunBasligi(ogunTipi),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '$toplamKalori kcal',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          // --- Kayıtlar ---
          if (kayitlar.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...kayitlar.map(
              (kayit) => _BesinKayitSatiri(kayit: kayit, isLoading: isLoading),
            ),
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
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_rounded,
                    color: const Color(0xFFF97316),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Ekle',
                    style: TextStyle(
                      color: const Color(0xFFF97316),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(kayit.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.redAccent.withValues(alpha: 0.2),
        child: const Icon(Icons.delete_outline, color: Colors.redAccent),
      ),
      confirmDismiss: (_) async {
        if (isLoading) return false;
        return true;
      },
      onDismissed: (_) {
        ref.read(nutritionProvider.notifier).ogunSil(kayit.id);
      },
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
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
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
                      color: Colors.white.withValues(alpha: 0.38),
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
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              ' kcal',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
  switch (ogunTipi) {
    case 'sabah':
      return const Color(0xFFF97316);
    case 'ogle':
      return const Color(0xFF3B82F6);
    case 'aksam':
      return const Color(0xFF8B5CF6);
    case 'atistirmalik':
      return const Color(0xFF22C55E);
    default:
      return const Color(0xFFF97316);
  }
}

String _formatMiktar(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}
