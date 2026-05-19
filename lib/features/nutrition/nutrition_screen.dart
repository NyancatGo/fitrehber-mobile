import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/beslenme_model.dart';
import 'providers/nutrition_provider.dart';
import 'widgets/daily_summary_dashboard.dart';
import 'widgets/meal_section_card.dart';
import 'widgets/water_tracker_section.dart';

class NutritionScreen extends ConsumerWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(nutritionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beslenme Takibi'),
        centerTitle: true,
        elevation: 0,
      ),
      body: state.isLoading && state.veri == null
          ? const Center(child: CircularProgressIndicator())
          : _GovdeParcasi(state: state),
    );
  }
}

class _GovdeParcasi extends ConsumerWidget {
  final NutritionState state;
  const _GovdeParcasi({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final veri = state.veri ?? GunlukBeslenmeModel(tarih: state.seciliTarih);
    const ogunSirasi = ['sabah', 'ogle', 'aksam', 'atistirmalik'];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // --- Tarih Seçici ---
        _GunSecici(seciliTarih: state.seciliTarih),
        const SizedBox(height: 20),

        // --- Günlük Özet Panosu (FatSecret tarzı) ---
        DailySummaryDashboard(veri: veri, hedefler: state.hedefler),
        const SizedBox(height: 20),

        // --- Hata varsa göster ---
        if (state.hata != null) ...[
          _HataKutusu(metin: state.hata!),
          const SizedBox(height: 14),
        ],

        // --- Öğün Blokları (FatSecret tarzı) ---
        ...ogunSirasi.map(
          (ogunTipi) => MealSectionCard(
            ogunTipi: ogunTipi,
            kayitlar: veri.ogunler[ogunTipi] ?? const [],
            isLoading: state.isLoading,
          ),
        ),

        // --- Su Takibi ---
        WaterTrackerSection(
          suMl: veri.suMl,
          hedefler: state.hedefler,
          onEkle: (ml) => ref.read(nutritionProvider.notifier).suEkle(ml),
          isLoading: state.isLoading,
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ---------- Gün Seçici ----------

class _GunSecici extends ConsumerWidget {
  final String seciliTarih;
  const _GunSecici({required this.seciliTarih});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bugun = DateTime.now();
    final gunler = List.generate(
      7,
      (i) => bugun.subtract(Duration(days: 3 - i)),
    );

    return SizedBox(
      height: 70,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: gunler.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final gun = gunler[i];
          final tarihStr = _tarihStr(gun);
          final secili = tarihStr == seciliTarih;
          const gunAdlari = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

          return GestureDetector(
            onTap: () => ref.read(nutritionProvider.notifier).load(tarihStr),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 56,
              decoration: BoxDecoration(
                gradient: secili
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF22D3EE), Color(0xFF6366F1)],
                      )
                    : null,
                color: secili ? null : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: secili
                      ? Colors.transparent
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    gunAdlari[gun.weekday - 1],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: secili
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${gun.day}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: secili ? Colors.white : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static String _tarihStr(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

// ---------- Hata Kutusu ----------

class _HataKutusu extends StatelessWidget {
  final String metin;
  const _HataKutusu({required this.metin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.25)),
      ),
      child: Text(
        metin,
        style: const TextStyle(
          color: Colors.redAccent,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
