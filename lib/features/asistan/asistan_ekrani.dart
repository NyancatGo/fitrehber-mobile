// ---------------------------------------------------------------------------
// YAPAY ZEKÂ ASİSTANI EKRANI
// ---------------------------------------------------------------------------
// Kullanıcının beslenme, antrenman ve genel sağlık konularında yapay zekâ
// asistanıyla sohbet ettiği ekran. Canlı günlük makro/kalori/su durum özeti,
// kişiselleştirilmiş akıllı başlangıç kartları, etkileşimli takip çipleri ve
// hızlı komut şeridi içerir.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/asistan_provider.dart';
import 'widgets/asistan_dusunuyor_gostergesi.dart';
import 'widgets/sohbet_balonu.dart';
import '../../core/theme/uygulama_temasi.dart';
import '../../shared/oturum_denetleyici.dart';
import '../../shared/models/beslenme_model.dart';
import '../../shared/models/sohbet_mesaji_model.dart';
import '../../shared/models/profil_model.dart';
import '../../shared/utils/beslenme_hesaplayici.dart';
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
    if (ref.read(asistanProvider).isLoading) return;
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
    final beslenme = ref.watch(beslenmeProvider);

    // Kullanıcı henüz mesaj göndermemişse karşılama kartlarını göster.
    final kullaniciMesajiVar = messages.any(
      (m) => m.role == SohbetMesajiRolu.kullanici,
    );

    final sonAsistanIndex = messages.lastIndexWhere(
      (m) => m.role == SohbetMesajiRolu.asistan && !m.isError,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('FitRehber AI'),
        backgroundColor: UygulamaTemasi.arkaPlan,
        elevation: 0,
        actions: [
          if (aiState.gunlukKota != null)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: UygulamaTemasi.yuzey,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: UygulamaTemasi.cizgi),
                ),
                child: Text(
                  '${aiState.gunlukKota!.remaining}/${aiState.gunlukKota!.limit}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: UygulamaTemasi.ikincilMetin,
                  ),
                ),
              ),
            ),
          if (kullaniciMesajiVar)
            IconButton(
              tooltip: 'Yeni sohbet',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: aiState.isLoading
                  ? null
                  : () => ref.read(asistanProvider.notifier).sohbetiTemizle(),
            ),
          IconButton(
            tooltip: 'Bilgi',
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'AI Asistan profil ve beslenme kayıtlarını analiz ederek kişiselleştirilmiş tavsiyeler sunar; tıbbi teşhis yerine geçmez.',
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
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.only(top: 16, bottom: 12),
                    itemCount: messages.length + (aiState.isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == messages.length) {
                        return const AsistanDusunuyorGostergesi();
                      }
                      final msg = messages[index];
                      return SohbetBalonu(
                        message: msg,
                        showSuggestions:
                            index == sonAsistanIndex && !aiState.isLoading,
                        onSuggestionTap: _kartaSoru,
                        onRetry: msg.isError
                            ? () => ref
                                  .read(asistanProvider.notifier)
                                  .yenidenDene(msg)
                            : null,
                        onActionApply: (eylemIdx) async {
                          final ok = await ref
                              .read(asistanProvider.notifier)
                              .eylemKartiniUygula(msg, eylemIndex: eylemIdx);
                          if (!context.mounted) return;
                          final eylem = msg.actions[eylemIdx];
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? '${eylem.ogunEtiketi} öğününe ${eylem.besinler.length} besin (${eylem.toplamKalori} kcal) eklendi!'
                                    : 'Öğün eklenirken bir sorun oluştu.',
                              ),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        },
                        onFeedback: (rating, reason) {
                          ref
                              .read(asistanProvider.notifier)
                              .geriBildirimVer(msg, rating, reason: reason);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Geri bildirimin kaydedildi, teşekkürler!',
                              ),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      );
                    },
                  )
                : _buildKarsilamaAlani(profile, beslenme),
          ),

          if (kullaniciMesajiVar)
            _buildHizliKomutSeridi(
              aiState.isLoading,
              profile,
              beslenme,
            ),

          // Giriş Alanı
          _buildInputArea(aiState.isLoading),
        ],
      ),
    );
  }

  Widget _buildKarsilamaAlani(
    ProfilModel? profile,
    BeslenmeDurumu beslenme,
  ) {
    final name = profile?.firstName.trim().isNotEmpty == true
        ? profile!.firstName.trim()
        : 'Sporcu';
    final hasGoal = profile?.goal != null && profile!.goal.trim().isNotEmpty;
    final goalText = hasGoal ? profile.goal.trim() : 'Sağlıklı Yaşam';
    final hedefler = profile != null
        ? BeslenmeHesaplayici.calculate(profile)
        : beslenme.hedefler;
    final veri = beslenme.veri;

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: UygulamaTemasi.yuzey,
            borderRadius: BorderRadius.circular(UygulamaTemasi.yaricap),
            border: Border.all(color: UygulamaTemasi.cizgi),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: UygulamaTemasi.anaRenk.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: UygulamaTemasi.anaRenk,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Merhaba, $name',
                          style: UygulamaTemasi.baslik(
                            fontSize: 22,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Profilin ve beslenme verilerinle senkron kişisel koçun',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: UygulamaTemasi.ikincilMetin,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: UygulamaTemasi.anaRenk.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: UygulamaTemasi.anaRenk.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.flag_rounded,
                          size: 15,
                          color: UygulamaTemasi.anaRenk,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Hedef: $goalText',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: UygulamaTemasi.anaRenk,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (profile?.weight != null && profile?.targetWeight != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: UygulamaTemasi.arkaPlan,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: UygulamaTemasi.cizgi),
                      ),
                      child: Text(
                        '${profile!.weight!.toStringAsFixed(0)} kg → ${profile.targetWeight!.toStringAsFixed(0)} kg',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: UygulamaTemasi.ikincilMetin,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _buildCanliDurumSeridi(veri, hedefler),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Sana özel hızlı sorular',
          style: UygulamaTemasi.baslik(fontSize: 18, height: 1.2),
        ),
        const SizedBox(height: 10),
        ..._kartlar(goalText, veri, hedefler).map((kart) => _buildKart(kart)),
      ],
    );
  }

  Widget _buildCanliDurumSeridi(
    GunlukBeslenmeModel? veri,
    BeslenmeHedefleri hedefler,
  ) {
    final alinanKcal = veri?.kaloriKcal ?? 0;
    final alinanProt = (veri?.proteinG ?? 0).round();
    final alinanSu = veri?.suMl ?? 0;

    final kalanKcal = (hedefler.kaloriHedef - alinanKcal).clamp(0, 9999);
    final kalanProt = (hedefler.proteinHedefG.round() - alinanProt).clamp(
      0,
      999,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: UygulamaTemasi.arkaPlan,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: UygulamaTemasi.cizgi),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildMiniMetrik(
              baslik: 'Kalori',
              deger: '$alinanKcal / ${hedefler.kaloriHedef}',
              altBilgi: kalanKcal > 0 ? '$kalanKcal kcal açık' : 'Hedef tamam',
            ),
          ),
          Container(width: 1, height: 30, color: UygulamaTemasi.cizgi),
          Expanded(
            child: _buildMiniMetrik(
              baslik: 'Protein',
              deger: '${alinanProt}g / ${hedefler.proteinHedefG.round()}g',
              altBilgi: kalanProt > 0 ? '${kalanProt}g eksik' : 'Hedef tamam',
            ),
          ),
          Container(width: 1, height: 30, color: UygulamaTemasi.cizgi),
          Expanded(
            child: _buildMiniMetrik(
              baslik: 'Su',
              deger: '$alinanSu ml',
              altBilgi: 'Hedef ${hedefler.suHedefMl} ml',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetrik({
    required String baslik,
    required String deger,
    required String altBilgi,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            baslik,
            style: const TextStyle(
              fontSize: 11,
              color: UygulamaTemasi.ikincilMetin,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            deger,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              color: UygulamaTemasi.anaMetin,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            altBilgi,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              color: UygulamaTemasi.anaRenk,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  List<_HizliKart> _kartlar(
    String hedef,
    GunlukBeslenmeModel? veri,
    BeslenmeHedefleri hedefler,
  ) {
    final h = hedef.toLowerCase();
    final dinamikKartlar = <_HizliKart>[];

    if (veri != null) {
      final kalanKcal = hedefler.kaloriHedef - veri.kaloriKcal;
      final kalanProt = (hedefler.proteinHedefG - veri.proteinG).round();
      final kayitSayisi = veri.ogunler.values.fold<int>(
        0,
        (top, liste) => top + liste.length,
      );

      if (kayitSayisi > 0 && (kalanProt > 15 || kalanKcal > 200)) {
        dinamikKartlar.add(
          _HizliKart(
            ikon: Icons.insights_rounded,
            renk: UygulamaTemasi.anaRenk,
            etiket: 'Canlı Veri',
            soru:
                'Bugün yediklerimi analiz et; kalan ${kalanKcal > 0 ? "$kalanKcal kcal ve " : ""}${kalanProt > 0 ? "${kalanProt}g protein " : ""}açığımı nasıl kapatırım?',
          ),
        );
      } else {
        dinamikKartlar.add(
          const _HizliKart(
            ikon: Icons.restaurant_menu_rounded,
            renk: UygulamaTemasi.anaRenk,
            etiket: 'Günlük Plan',
            soru:
                'Bugünkü kalori ve protein hedefime uygun öğün planı çıkarır mısın?',
          ),
        );
      }
    }

    if (h.contains('kilo') &&
            (h.contains('ver') || h.contains('zayıf') || h.contains('kaybet')) ||
        h.contains('yağ')) {
      return [
        ...dinamikKartlar,
        const _HizliKart(
          ikon: Icons.local_fire_department,
          renk: UygulamaTemasi.anaRenk,
          etiket: 'Yağ Yakımı',
          soru: 'Düşük kalorili, yüksek proteinli ve tok tutan akşam öğünü öner',
        ),
        const _HizliKart(
          ikon: Icons.query_stats_rounded,
          renk: UygulamaTemasi.anaRenk,
          etiket: '7 Günlük Trend',
          soru: 'Son 7 gün kalori ve protein istikrarımı değerlendir',
        ),
        const _HizliKart(
          ikon: Icons.directions_run_rounded,
          renk: UygulamaTemasi.anaRenk,
          soru: 'Yağ yakımını hızlandıracak antrenman ve kardiyo dengesi nasıl olmalı?',
        ),
      ];
    }

    if (h.contains('kas') || h.contains('bulk') || h.contains('güç')) {
      return [
        ...dinamikKartlar,
        const _HizliKart(
          ikon: Icons.fitness_center,
          renk: UygulamaTemasi.anaRenk,
          etiket: 'Hipertrofi',
          soru: 'Kas gelişimi için antrenman öncesi ve sonrası ne yemeliyim?',
        ),
        const _HizliKart(
          ikon: Icons.query_stats_rounded,
          renk: UygulamaTemasi.anaRenk,
          etiket: '7 Günlük Trend',
          soru: 'Son 7 gün protein ve kalori ortalamam hedefime uygun mu?',
        ),
        const _HizliKart(
          ikon: Icons.calendar_month,
          renk: UygulamaTemasi.anaRenk,
          soru: 'Haftalık split antrenman programı ve toparlanma stratejisi öner',
        ),
      ];
    }

    return [
      ...dinamikKartlar,
      const _HizliKart(
        ikon: Icons.food_bank,
        renk: UygulamaTemasi.anaRenk,
        etiket: 'Beslenme Koçu',
        soru: 'Sağlıklı beslenme için günlük dengeli öğün planı oluştur',
      ),
      const _HizliKart(
        ikon: Icons.query_stats_rounded,
        renk: UygulamaTemasi.anaRenk,
        etiket: '7 Günlük Trend',
        soru: 'Son 7 gündeki beslenme ve su tüketimi istikrarımı değerlendir',
      ),
      const _HizliKart(
        ikon: Icons.directions_run,
        renk: UygulamaTemasi.anaRenk,
        soru: 'Hedefime uygun haftalık egzersiz rutini öner',
      ),
    ];
  }

  Widget _buildKart(_HizliKart kart) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: UygulamaTemasi.yuzey,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _kartaSoru(kart.soru),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: UygulamaTemasi.cizgi),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (kart.etiket != null) ...[
                        Text(
                          kart.etiket!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: UygulamaTemasi.anaRenk,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        kart.soru,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: UygulamaTemasi.anaMetin,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 13,
                  color: UygulamaTemasi.ikincilMetin,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHizliKomutSeridi(
    bool isLoading,
    ProfilModel? profile,
    BeslenmeDurumu beslenme,
  ) {
    final hedefler = profile != null
        ? BeslenmeHesaplayici.calculate(profile)
        : beslenme.hedefler;
    final veri = beslenme.veri;
    final kalanProt = veri != null
        ? (hedefler.proteinHedefG - veri.proteinG).round()
        : 0;

    final komutlar = <(String etiket, String soru)>[
      (
        'Bugünkü Durumum',
        'Bugünkü kalori, makro ve su durumumu değerlendirir misin?',
      ),
      (
        kalanProt > 15 ? '${kalanProt}g Protein Açığım' : 'Akşama Ne Yesem?',
        kalanProt > 15
            ? 'Bugün kalan ${kalanProt}g protein açığımı hangi besinlerle kapatabilirim?'
            : 'Bugün yediklerime göre akşam öğünü için ne önerirsin?',
      ),
      (
        '7 Günlük Analiz',
        'Son 7 gündeki beslenme ve protein istikrarımı analiz et',
      ),
      (
        'Antrenman Öğünü',
        'Hedefime göre antrenman öncesi ve sonrası ideal öğün nedir?',
      ),
    ];

    return Container(
      height: 42,
      decoration: const BoxDecoration(
        color: UygulamaTemasi.arkaPlan,
        border: Border(top: BorderSide(color: UygulamaTemasi.cizgi)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: komutlar.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = komutlar[index];
          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: isLoading ? null : () => _kartaSoru(item.$2),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: UygulamaTemasi.yuzey,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: UygulamaTemasi.cizgi),
              ),
              alignment: Alignment.center,
              child: Text(
                item.$1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isLoading
                      ? UygulamaTemasi.ikincilMetin
                      : UygulamaTemasi.anaMetin,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _mesajGonder() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    ref.read(asistanProvider.notifier).sendMessage(text);
    _controller.clear();
    _scrollToBottom();
  }

  Widget _buildInputArea(bool isLoading) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: UygulamaTemasi.yuzey,
        border: Border(top: BorderSide(color: UygulamaTemasi.cizgi)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: 4,
                minLines: 1,
                enabled: !isLoading,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) {
                  if (!isLoading) _mesajGonder();
                },
                decoration: InputDecoration(
                  hintText: isLoading
                      ? 'Lütfen bekleyin...'
                      : 'Beslenme, öğün önerisi, antrenman...',
                  hintStyle: const TextStyle(
                    color: UygulamaTemasi.ikincilMetin,
                    fontSize: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: UygulamaTemasi.cizgi),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: UygulamaTemasi.cizgi),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(
                      color: UygulamaTemasi.anaRenk,
                      width: 1.4,
                    ),
                  ),
                  filled: true,
                  fillColor: UygulamaTemasi.arkaPlan,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                style: const TextStyle(
                  color: UygulamaTemasi.anaMetin,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 10),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                final canSend = !isLoading && value.text.trim().isNotEmpty;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: canSend
                        ? UygulamaTemasi.anaRenk
                        : UygulamaTemasi.cizgi,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: IconButton(
                    tooltip: 'Gönder',
                    icon: Icon(
                      Icons.send_rounded,
                      color: canSend
                          ? UygulamaTemasi.anaUstune
                          : UygulamaTemasi.ikincilMetin,
                      size: 20,
                    ),
                    onPressed: canSend ? _mesajGonder : null,
                  ),
                );
              },
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
  final String? etiket;
  const _HizliKart({
    required this.ikon,
    required this.renk,
    required this.soru,
    this.etiket,
  });
}
