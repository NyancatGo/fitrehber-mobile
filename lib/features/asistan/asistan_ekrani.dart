// ---------------------------------------------------------------------------
// YAPAY ZEKÂ ASİSTANI EKRANI
// ---------------------------------------------------------------------------
// Kullanıcının beslenme, antrenman ve genel sağlık konularında yapay zekâ
// asistanıyla sohbet ettiği ekran. Sohbet balonları, "düşünüyor" göstergesi
// ve hızlı soru kartları içerir.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/asistan_provider.dart';
import 'widgets/asistan_dusunuyor_gostergesi.dart';
import 'widgets/sohbet_balonu.dart';
import '../../core/theme/uygulama_temasi.dart';
import '../../shared/oturum_denetleyici.dart';
import '../../shared/models/sohbet_mesaji_model.dart';
import '../../shared/models/profil_model.dart';
import '../../shared/models/beslenme_model.dart';
import '../beslenme/providers/beslenme_provider.dart';

/// Yapay zekâ asistanıyla sohbet edilen ekran.
class AsistanEkrani extends ConsumerStatefulWidget {
  const AsistanEkrani({super.key});

  @override
  ConsumerState<AsistanEkrani> createState() => _AsistanEkraniDurumu();
}

class _AsistanEkraniDurumu extends ConsumerState<AsistanEkrani> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _kartaSoru(String soru) {
    ref.read(asistanProvider.notifier).sendMessage(soru);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsistanDurumu>(asistanProvider, (previous, next) {
      if (previous == null) return;
      if (previous.messages.length != next.messages.length ||
          previous.isLoading != next.isLoading) {
        _scrollToBottom();
      }
    });

    final aiState = ref.watch(asistanProvider);
    final messages = aiState.messages;
    final profile = ref.watch(oturumDenetleyiciProvider).profile;
    final nutritionState = ref.watch(beslenmeProvider);
    final nutritionData = nutritionState.veri;

    // Kullanıcı henüz mesaj göndermemişse karşılama kartlarını göster.
    final kullaniciMesajiVar = messages.any(
      (m) => m.role == SohbetMesajiRolu.kullanici,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('FitRehber AI'),
        centerTitle: true,
        backgroundColor: UygulamaTemasi.arkaPlan,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'AI Asistan sadece tavsiye niteliğindedir. Tıbbi bir teşhis veya tedavi sunmaz.',
                  ),
                  duration: Duration(seconds: 4),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: kullaniciMesajiVar
                ? ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 16, bottom: 8),
                    itemCount: messages.length + (aiState.isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == messages.length) {
                        return const AsistanDusunuyorGostergesi();
                      }
                      return SohbetBalonu(message: messages[index]);
                    },
                  )
                : _buildKarsilamaAlani(profile, nutritionData),
          ),

          // Giriş Alanı
          _buildInputArea(aiState.isLoading),
        ],
      ),
    );
  }

  Widget _buildKarsilamaAlani(
    ProfilModel? profile,
    GunlukBeslenmeModel? nutrition,
  ) {
    final name = profile?.firstName ?? 'Sporcu';
    final hasGoal = profile?.goal != null && profile!.goal.isNotEmpty;
    final goalText = hasGoal ? profile.goal : 'Sağlıklı Yaşam';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      children: [
        // Başlık
        Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF22D3EE), Color(0xFF6366F1)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.fitness_center,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Merhaba, $name! 👋',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Text(
                'Hedef: $goalText',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF22D3EE),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Günlük özet kartı
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text(
                        '💧 Su Tüketimi',
                        style: TextStyle(fontSize: 12, color: Colors.white60),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${nutrition?.suMl ?? 0} ml',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF06B6D4),
                        ),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 32, color: Colors.white12),
                  Column(
                    children: [
                      const Text(
                        '🔥 Kalori',
                        style: TextStyle(fontSize: 12, color: Colors.white60),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${nutrition?.kaloriKcal ?? 0} kcal',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFF97316),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Bugünkü tüketim bilgilerin asistanın hafızasına entegre edildi. Beslenme, antrenman ve hedeflerine yönelik her şeyi sorabilirsin!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.45),
                height: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Hedef bazlı öneri kartları
        Text(
          'Hızlı Başlangıç',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.45),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        ..._kartlar(goalText).map((kart) => _buildKart(kart)),
      ],
    );
  }

  List<_HizliKart> _kartlar(String hedef) {
    final h = hedef.toLowerCase();

    if (h.contains('kilo') &&
        (h.contains('ver') || h.contains('zayıf') || h.contains('kaybet'))) {
      return [
        _HizliKart(
          ikon: Icons.local_fire_department,
          renk: const Color(0xFF22C55E),
          soru: 'Yağ yakımını hızlandıracak kardiyo programı öner',
        ),
        _HizliKart(
          ikon: Icons.restaurant,
          renk: const Color(0xFF22C55E),
          soru: 'Düşük kalorili ve tok tutan tarifler paylaş',
        ),
        _HizliKart(
          ikon: Icons.calculate,
          renk: const Color(0xFF22C55E),
          soru: 'Günlük kalori açığımı nasıl hesaplayabilirim?',
        ),
      ];
    }

    if (h.contains('kas') || h.contains('bulk') || h.contains('güç')) {
      return [
        _HizliKart(
          ikon: Icons.fitness_center,
          renk: const Color(0xFFF97316),
          soru: 'Kas kütlesi için günlük protein ve makro dağılımı çıkar',
        ),
        _HizliKart(
          ikon: Icons.calendar_month,
          renk: const Color(0xFFF97316),
          soru: 'Haftalık split antrenman programı öner',
        ),
        _HizliKart(
          ikon: Icons.monitor_weight,
          renk: const Color(0xFFF97316),
          soru: 'Kiloma göre almam gereken günlük kalori fazlasını hesapla',
        ),
      ];
    }

    return [
      _HizliKart(
        ikon: Icons.food_bank,
        renk: const Color(0xFF22D3EE),
        soru: 'Sağlıklı beslenme için günlük öğün planı oluştur',
      ),
      _HizliKart(
        ikon: Icons.directions_run,
        renk: const Color(0xFF22D3EE),
        soru: 'Yeni başlayanlar için haftalık egzersiz rutini öner',
      ),
      _HizliKart(
        ikon: Icons.water_drop,
        renk: const Color(0xFF22D3EE),
        soru: 'Su tüketimimi nasıl artırabilirim?',
      ),
    ];
  }

  Widget _buildKart(_HizliKart kart) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _kartaSoru(kart.soru),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: kart.renk.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(kart.ikon, size: 20, color: kart.renk),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    kart.soru,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 13,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea(bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: UygulamaTemasi.yuzey,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: 3,
                minLines: 1,
                enabled: !isLoading,
                decoration: InputDecoration(
                  hintText: isLoading
                      ? 'Lütfen bekleyin...'
                      : 'Beslenme, antrenman, sağlık...',
                  hintStyle: const TextStyle(
                    color: UygulamaTemasi.ikincilMetin,
                    fontSize: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: UygulamaTemasi.arkaPlan,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                color: isLoading
                    ? UygulamaTemasi.yuzey
                    : UygulamaTemasi.anaRenk,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  Icons.send_rounded,
                  color: isLoading ? UygulamaTemasi.ikincilMetin : Colors.white,
                  size: 22,
                ),
                onPressed: isLoading
                    ? null
                    : () {
                        final text = _controller.text.trim();
                        if (text.isNotEmpty) {
                          ref.read(asistanProvider.notifier).sendMessage(text);
                          _controller.clear();
                          _scrollToBottom();
                        }
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _HizliKart {
  final IconData ikon;
  final Color renk;
  final String soru;
  const _HizliKart({
    required this.ikon,
    required this.renk,
    required this.soru,
  });
}
