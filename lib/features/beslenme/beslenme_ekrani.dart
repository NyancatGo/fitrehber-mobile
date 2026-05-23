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

/// Ekranın asıl gövdesi: gün seçici, özet panosu, öğünler ve su takibi.
class _GovdeParcasi extends ConsumerWidget {
  final BeslenmeDurumu state;
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
        GunlukOzetPaneli(veri: veri, hedefler: state.hedefler),
        const SizedBox(height: 20),

        // --- Hata varsa göster ---
        if (state.hata != null) ...[
          _HataKutusu(metin: state.hata!),
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
    );
  }
}

// ---------- Gün Seçici ----------
//
// UX:
//   - Sinirlar: [profil.joinDate, bugun + 30 gun]. Yoksa 6 ay geri fallback.
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
    return DateTime(now.year, now.month, now.day).add(const Duration(days: 30));
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF22D3EE),
              onPrimary: Colors.white,
              surface: Color(0xFF151D2B),
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF0F1626),
            ),
          ),
          child: child!,
        );
      },
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
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            ayEtiketi,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ),
        SizedBox(
          height: 70,
          child: Row(
            children: [
              _TakvimButonu(onTap: _takvimAc),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < gunler.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        _GunChip(
                          gun: gunler[i],
                          secili: _tarihStr(gunler[i]) == widget.seciliTarih,
                          isToday: _ayniGun(gunler[i], bugun),
                          disabled:
                              gunler[i].isBefore(start) ||
                              gunler[i].isAfter(end),
                          onTap:
                              (gunler[i].isBefore(start) ||
                                  gunler[i].isAfter(end))
                              ? null
                              : () => ref
                                    .read(beslenmeProvider.notifier)
                                    .load(_tarihStr(gunler[i])),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
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
        width: 48,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: const Icon(
          Icons.calendar_month_outlined,
          color: Color(0xFF22D3EE),
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
    final fadedColor = Colors.white.withValues(alpha: 0.18);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 56,
        decoration: BoxDecoration(
          gradient: secili && !disabled
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF22D3EE), Color(0xFF6366F1)],
                )
              : null,
          color: secili && !disabled
              ? null
              : Colors.white.withValues(alpha: disabled ? 0.02 : 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: secili && !disabled
                ? Colors.transparent
                : (isToday && !disabled
                      ? const Color(0xFF22D3EE).withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: disabled ? 0.04 : 0.08)),
            width: isToday && !secili ? 1.2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _kGunAdlari[gun.weekday - 1],
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: disabled
                    ? fadedColor
                    : (secili
                          ? Colors.white
                          : (isToday
                                ? const Color(0xFF22D3EE)
                                : Colors.white.withValues(alpha: 0.5))),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${gun.day}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: disabled
                    ? fadedColor
                    : (secili ? Colors.white : Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
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
