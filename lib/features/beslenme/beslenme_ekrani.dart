// ---------------------------------------------------------------------------
// BESLENME TAKİBİ EKRANI
// ---------------------------------------------------------------------------
// Kullanıcının günlük beslenmesini takip ettiği ana ekran. Yukarıdan aşağıya:
//   * Gün seçici (takvim + 7 günlük yatay şerit),
//   * Günlük özet panosu (kalori ve makro hedeflerine göre ilerleme),
//   * Dört öğün bloğu (sabah, öğle, akşam, atıştırmalık),
//   * Su takibi bölümü.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/uygulama_temasi.dart';
import '../../shared/models/beslenme_model.dart';
import '../profil/providers/profil_provider.dart';
import 'providers/beslenme_provider.dart';
import 'widgets/gunluk_ozet_paneli.dart';
import 'widgets/ogun_bolumu_karti.dart';
import 'widgets/su_takip_bolumu.dart';

/// Günlük beslenme ve su takibinin yapıldığı ana ekran.
class BeslenmeEkrani extends ConsumerWidget {
  const BeslenmeEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(beslenmeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Beslenme Takibi'), elevation: 0),
      body: state.isLoading && state.veri == null
          ? const Center(child: CircularProgressIndicator())
          : _GovdeParcasi(state: state),
    );
  }
}

/// Ekranın asıl gövdesi: gün seçici, özet panosu, öğünler ve su takibi.
class _GovdeParcasi extends ConsumerWidget {
  final BeslenmeDurumu state;
  const _GovdeParcasi({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final veri = state.veri ?? GunlukBeslenmeModel(tarih: state.seciliTarih);
    const ogunSirasi = ['sabah', 'ogle', 'aksam', 'atistirmalik'];

    return RefreshIndicator(
      color: UygulamaTemasi.anaRenk,
      backgroundColor: UygulamaTemasi.yuzey,
      onRefresh: () =>
          ref.read(beslenmeProvider.notifier).load(state.seciliTarih),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // --- Tarih Seçici ---
          _GunSecici(seciliTarih: state.seciliTarih),
          const SizedBox(height: 16),

          // --- Günlük Özet Panosu (FatSecret tarzı) ---
          GunlukOzetPaneli(veri: veri, hedefler: state.hedefler),
          const SizedBox(height: 16),

          // --- Çevrimdışı / bekleyen senkron şeridi ---
          if (state.cevrimdisiMi || state.bekleyenIslemSayisi > 0) ...[
            _CevrimdisiDurumKutusu(
              cevrimdisiMi: state.cevrimdisiMi,
              bekleyenSayisi: state.bekleyenIslemSayisi,
              isLoading: state.isLoading,
              onYenile: () =>
                  ref.read(beslenmeProvider.notifier).load(state.seciliTarih),
            ),
            const SizedBox(height: 14),
          ],

          // --- Hata varsa göster ---
          if (state.hata != null) ...[
            _HataKutusu(metin: state.hata!),
            const SizedBox(height: 14),
          ],

          // --- Gün boşsa: önceki günü kopyala (web paritesi) ---
          if (veri.ogunler.values.every((l) => l.isEmpty)) ...[
            _OncekiGunKopyalaButonu(isLoading: state.isLoading),
            const SizedBox(height: 14),
          ],

          // --- Öğün Blokları (FatSecret tarzı) ---
          ...ogunSirasi.map(
            (ogunTipi) => OgunBolumuKarti(
              ogunTipi: ogunTipi,
              kayitlar: veri.ogunler[ogunTipi] ?? const [],
              isLoading: state.isLoading,
            ),
          ),

          // --- Su Takibi ---
          SuTakipBolumu(
            suMl: veri.suMl,
            hedefler: state.hedefler,
            onEkle: (ml) => ref.read(beslenmeProvider.notifier).suEkle(ml),
            isLoading: state.isLoading,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ---------- Gün Seçici ----------
//
// UX:
//   - Sinirlar: [profil.joinDate, bugun]. Yoksa 6 ay geri fallback.
//   - Pencere: secili tarih ORTADA, 3 gun once + 3 gun sonra = 7 chip.
//   - Sinir disindaki chip'ler disabled (gri, tap edilemez).
//   - Soldaki takvim ikonu showDatePicker'i acar - 1 haftadan uzak siçramalar.
//   - Ust kismda "Mayis 2026" ay/yil etiketi (secili tarihe gore).

const _kGunAdlari = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
const _kAyAdlari = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

/// Bir tarihi `YYYY-AA-GG` biçiminde metne çevirir (API ile uyumlu).
String _tarihStr(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

/// İki tarihin (saat farkını yok sayarak) aynı güne denk gelip gelmediğini döner.
bool _ayniGun(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _GunSecici extends ConsumerStatefulWidget {
  final String seciliTarih;
  const _GunSecici({required this.seciliTarih});

  @override
  ConsumerState<_GunSecici> createState() => _GunSeciciState();
}

class _GunSeciciState extends ConsumerState<_GunSecici> {
  // Pencerenin orta noktasi (index 3 chip'ine denk gelir).
  // Yalnizca takvimden tarih secildiginde guncellenir; chip'e tap ise sadece
  // active seciliTarih'i degistirir, pencere SABIT kalir.
  late DateTime _windowCenter;

  @override
  void initState() {
    super.initState();
    // Pencere merkezi widget yaratildiginda set edilir, asla otomatik kaymaz.
    _windowCenter = _seciliDt();
  }

  DateTime _baslangic() {
    final profil = ref.read(profilProvider).valueOrNull;
    final jd = profil?.joinDate;
    if (jd != null) return DateTime(jd.year, jd.month, jd.day);
    final now = DateTime.now();
    return DateTime(now.year, now.month - 6, now.day);
  }

  DateTime _bitis() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _seciliDt() {
    try {
      return DateTime.parse(widget.seciliTarih);
    } catch (_) {
      return DateTime.now();
    }
  }

  Future<void> _takvimAc() async {
    final start = _baslangic();
    final end = _bitis();
    final initial = _seciliDt();
    final clampedInitial = initial.isBefore(start)
        ? start
        : (initial.isAfter(end) ? end : initial);
    final picked = await showDatePicker(
      context: context,
      initialDate: clampedInitial,
      firstDate: start,
      lastDate: end,
      helpText: 'Tarih seç',
      cancelText: 'İptal',
      confirmText: 'Seç',
    );
    if (picked != null) {
      // Pencereyi yeni tarihte re-center et + secimi degistir
      setState(() => _windowCenter = picked);
      ref.read(beslenmeProvider.notifier).load(_tarihStr(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Profili izle (joinDate degisirse yeniden hesaplansin)
    ref.watch(profilProvider);

    final start = _baslangic();
    final end = _bitis();
    final bugun = DateTime.now();

    // Pencere merkezi: initState'te ilk yaratilirken set edildi, sonra
    // sadece takvim ile guncellenir. Chip'e tap pencereye dokunmaz.
    final center = _windowCenter;

    // 7 chip: center ortada (index 3), 3 once + 3 sonra
    final gunler = List.generate(7, (i) => center.add(Duration(days: i - 3)));

    // Ay etiketi: PENCERE merkezine gore (kullanici hangi haftadaysa)
    final ayEtiketi = '${_kAyAdlari[center.month - 1]} ${center.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                ayEtiketi,
                style: UygulamaTemasi.baslik(fontSize: 18, height: 1.2),
              ),
            ),
            if (!_ayniGun(_seciliDt(), bugun)) ...[
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
                onPressed: () {
                  final bugunTarih = DateTime(
                    bugun.year,
                    bugun.month,
                    bugun.day,
                  );
                  setState(() => _windowCenter = bugunTarih);
                  ref
                      .read(beslenmeProvider.notifier)
                      .load(_tarihStr(bugunTarih));
                },
                icon: const Icon(Icons.today_rounded, size: 16),
                label: const Text('Bugün'),
              ),
              const SizedBox(width: 6),
            ],
            _TakvimButonu(onTap: _takvimAc),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < gunler.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _GunChip(
                    gun: gunler[i],
                    secili: _tarihStr(gunler[i]) == widget.seciliTarih,
                    isToday: _ayniGun(gunler[i], bugun),
                    disabled:
                        gunler[i].isBefore(start) || gunler[i].isAfter(end),
                    onTap: (gunler[i].isBefore(start) || gunler[i].isAfter(end))
                        ? null
                        : () => ref
                              .read(beslenmeProvider.notifier)
                              .load(_tarihStr(gunler[i])),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TakvimButonu extends StatelessWidget {
  final VoidCallback onTap;
  const _TakvimButonu({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: UygulamaTemasi.yuzey,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: UygulamaTemasi.cizgi),
        ),
        child: const Icon(
          Icons.calendar_month_outlined,
          color: UygulamaTemasi.anaRenk,
          size: 22,
        ),
      ),
    );
  }
}

class _GunChip extends StatelessWidget {
  final DateTime gun;
  final bool secili;
  final bool isToday;
  final bool disabled;
  final VoidCallback? onTap;

  const _GunChip({
    required this.gun,
    required this.secili,
    required this.isToday,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final soluk = UygulamaTemasi.ikincilMetin.withValues(alpha: 0.4);
    final seciliVeAcik = secili && !disabled;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: seciliVeAcik ? UygulamaTemasi.anaRenk : UygulamaTemasi.yuzey,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: seciliVeAcik
                ? UygulamaTemasi.anaRenk
                : (isToday && !disabled
                      ? UygulamaTemasi.anaRenk
                      : UygulamaTemasi.cizgi),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _kGunAdlari[gun.weekday - 1],
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: disabled
                    ? soluk
                    : (seciliVeAcik
                          ? UygulamaTemasi.anaUstune
                          : (isToday
                                ? UygulamaTemasi.anaRenk
                                : UygulamaTemasi.ikincilMetin)),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${gun.day}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: disabled
                    ? soluk
                    : (seciliVeAcik
                          ? UygulamaTemasi.anaUstune
                          : UygulamaTemasi.anaMetin),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Hata & Çevrimdışı Durum Kutuları ----------

class _CevrimdisiDurumKutusu extends StatelessWidget {
  final bool cevrimdisiMi;
  final int bekleyenSayisi;
  final bool isLoading;
  final VoidCallback onYenile;

  const _CevrimdisiDurumKutusu({
    required this.cevrimdisiMi,
    required this.bekleyenSayisi,
    required this.isLoading,
    required this.onYenile,
  });

  @override
  Widget build(BuildContext context) {
    final metin = bekleyenSayisi > 0
        ? 'Çevrimdışı kaydedilen $bekleyenSayisi değişiklik bağlantı kurulduğunda eşitlenecek.'
        : 'Çevrimdışı görünüm — son kaydedilen günlük veriler gösteriliyor.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: UygulamaTemasi.yuzey,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: UygulamaTemasi.cizgi),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_sync_outlined,
            color: UygulamaTemasi.anaRenk,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              metin,
              style: const TextStyle(
                color: UygulamaTemasi.ikincilMetin,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: isLoading ? null : onYenile,
            child: const Text('Eşitle'),
          ),
        ],
      ),
    );
  }
}

class _HataKutusu extends StatelessWidget {
  final String metin;
  const _HataKutusu({required this.metin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: UygulamaTemasi.hata.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: UygulamaTemasi.hata.withValues(alpha: 0.3)),
      ),
      child: Text(
        metin,
        style: const TextStyle(
          color: UygulamaTemasi.hata,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------- Önceki Günü Kopyala ----------
//
// Gün boşken gösterilir; bir önceki günün öğünlerini bu güne kopyalar
// (web'deki "öğünleri kopyala" özelliğinin mobil karşılığı).

class _OncekiGunKopyalaButonu extends ConsumerWidget {
  final bool isLoading;
  const _OncekiGunKopyalaButonu({required this.isLoading});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: isLoading
            ? null
            : () async {
                final ok = await ref
                    .read(beslenmeProvider.notifier)
                    .ogunleriKopyala();
                if (!context.mounted) return;
                final mesaj = ok
                    ? 'Önceki günün öğünleri kopyalandı.'
                    : (ref.read(beslenmeProvider).hata ??
                          'Kopyalanacak öğün bulunamadı.');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(mesaj),
                    backgroundColor: ok
                        ? UygulamaTemasi.yuzey
                        : UygulamaTemasi.hata,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
        icon: const Icon(Icons.copy_all_outlined, size: 18),
        style: OutlinedButton.styleFrom(
          foregroundColor: UygulamaTemasi.anaRenk,
          side: const BorderSide(color: UygulamaTemasi.cizgi),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        label: const Text(
          'Önceki günü kopyala',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
