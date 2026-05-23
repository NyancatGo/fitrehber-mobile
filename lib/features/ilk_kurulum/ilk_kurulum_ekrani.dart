// ---------------------------------------------------------------------------
// İLK KURULUM EKRANI
// ---------------------------------------------------------------------------
// Yeni kullanıcının profilini 4 adımda tamamlatır: kimlik, ölçüler, hedef ve
// özet. Adımlar elle kaydırılamaz; geçiş sadece "İleri" doğrulamasından sonra
// olur. Backend'e giden JSON key'leri web/API kontratı olduğu için korunur.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/uygulama_temasi.dart';
import '../../shared/hata_yardimcilari.dart';
import '../../shared/ilk_kurulum_sabitleri.dart';
import '../../shared/oturum_denetleyici.dart';
import '../../shared/widgets/oturum_yukleme.dart';
import '../profil/providers/profil_provider.dart';

// Hedef listesi tek kaynaktan okunur; profil düzenleme ekranı da aynı listeyi
// kullanır, böylece mobil/web/API hedef seçenekleri ayrışmaz.

/// Yeni kullanıcının profilini tamamladığı 4 adımlı kurulum ekranı.
class IlkKurulumEkrani extends ConsumerStatefulWidget {
  const IlkKurulumEkrani({super.key});

  @override
  ConsumerState<IlkKurulumEkrani> createState() => _IlkKurulumEkraniDurumu();
}

class _IlkKurulumEkraniDurumu extends ConsumerState<IlkKurulumEkrani> {
  final _formAnahtari = GlobalKey<FormState>();
  final _sayfaDenetleyici = PageController();
  late final TextEditingController _adDenetleyici;
  late final TextEditingController _soyadDenetleyici;
  late final TextEditingController _boyDenetleyici;
  late final TextEditingController _kiloDenetleyici;
  late final TextEditingController _hedefKiloDenetleyici;
  late final TextEditingController _hedefDenetleyici;

  int _adim = 0;
  DateTime? _dogumTarihi;
  // Kullanıcı kesin seçim yapmadan ileri gidemez. "B" (Belirtmem) ilk kurulum
  // akışında kabul edilmiyor; mevcut profilden de E/K dışındaki değerleri boş
  // sayıyoruz.
  String _cinsiyet = '';
  bool _kaydediliyor = false;

  /// Sabit hedef listesine kısa erişim; değerleri değiştirme, backend ile ortaktır.
  List<String> get _izinliHedefler => onboardingGoalChoices;

  @override
  void initState() {
    super.initState();
    final profil = ref.read(oturumDenetleyiciProvider).profile;
    // Ad/Soyad: Google ile giriş yapıldıysa profil bu alanları Google
    // hesabından dolu getirir; kullanıcı değiştirebilir.
    _adDenetleyici = TextEditingController(text: profil?.firstName ?? '');
    _soyadDenetleyici = TextEditingController(text: profil?.lastName ?? '');
    _boyDenetleyici = TextEditingController(
      text: _sayiFormatla(profil?.height),
    );
    _kiloDenetleyici = TextEditingController(
      text: _sayiFormatla(profil?.weight),
    );
    _hedefKiloDenetleyici = TextEditingController(
      text: _sayiFormatla(profil?.targetWeight),
    );
    _hedefDenetleyici = TextEditingController(text: profil?.goal ?? '');
    _dogumTarihi = profil?.birthDate;
    // Mevcut profilden cinsiyet okunurken yalnızca "E" veya "K" kabul edilir.
    // "B" veya boş değer, ekranda kullanıcıya yeniden seçim yaptırır.
    final mevcutCinsiyet = profil?.gender ?? '';
    _cinsiyet = (mevcutCinsiyet == 'E' || mevcutCinsiyet == 'K')
        ? mevcutCinsiyet
        : '';
  }

  @override
  void dispose() {
    _sayfaDenetleyici.dispose();
    _adDenetleyici.dispose();
    _soyadDenetleyici.dispose();
    _boyDenetleyici.dispose();
    _kiloDenetleyici.dispose();
    _hedefKiloDenetleyici.dispose();
    _hedefDenetleyici.dispose();
    super.dispose();
  }

  /// Tüm adımlardaki bilgileri son kez doğrular ve profili sunucuya kaydeder.
  ///
  /// Eksik bir alan varsa kullanıcı ilgili adıma geri götürülür; kayıt
  /// başarılı olursa ana ekrana geçilir.
  Future<void> _kaydet() async {
    if (_kaydediliyor) return;
    if (!_formAnahtari.currentState!.validate()) return;
    // Fitness hedefi artık serbest metin değil; bu yüzden form validator yerine
    // sabit liste kontrolüyle manuel doğruluyoruz.
    if (_adDenetleyici.text.trim().isEmpty ||
        _soyadDenetleyici.text.trim().isEmpty) {
      _mesajGoster('Ad ve soyad gerekli.');
      _adimaGit(0);
      return;
    }
    if (_cinsiyet.isEmpty) {
      _mesajGoster('Cinsiyet seç.');
      _adimaGit(0);
      return;
    }
    if (_dogumTarihi == null) {
      _mesajGoster('Doğum tarihini seç.');
      _adimaGit(0);
      return;
    }
    if (!_izinliHedefler.contains(_hedefDenetleyici.text)) {
      _mesajGoster('Fitness hedefi seç.');
      _adimaGit(2);
      return;
    }

    setState(() => _kaydediliyor = true);

    try {
      await ref.read(oturumDenetleyiciProvider.notifier).ilkKurulumuTamamla({
        'first_name': _adDenetleyici.text.trim(),
        'last_name': _soyadDenetleyici.text.trim(),
        'cinsiyet': _cinsiyet,
        'dogum_tarihi': _dogumTarihi!.toIso8601String().split('T').first,
        'boy': _ondalikSayiyaCevir(_boyDenetleyici.text),
        'kilo': _ondalikSayiyaCevir(_kiloDenetleyici.text),
        'hedef_kilo': _ondalikSayiyaCevir(_hedefKiloDenetleyici.text),
        'fitness_hedefi': _hedefDenetleyici.text.trim(),
      });
      ref.invalidate(profilProvider);
      if (mounted) context.go('/');
    } catch (error) {
      if (mounted) _mesajGoster(kullaniciDostuHata(error));
    } finally {
      if (mounted) setState(() => _kaydediliyor = false);
    }
  }

  /// Doğum tarihi seçici takvimini açar ve seçilen tarihi kaydeder.
  Future<void> _dogumTarihiSec() async {
    final simdi = DateTime.now();
    final seciliTarih = await showDatePicker(
      context: context,
      initialDate:
          _dogumTarihi ?? DateTime(simdi.year - 25, simdi.month, simdi.day),
      firstDate: DateTime(simdi.year - 100),
      lastDate: simdi,
    );
    if (seciliTarih != null && mounted) {
      setState(() => _dogumTarihi = seciliTarih);
    }
  }

  /// Belirtilen adıma yumuşak bir geçiş animasyonuyla ilerler.
  void _adimaGit(int adim) {
    final sonraki = adim.clamp(0, 3);
    _sayfaDenetleyici.animateToPage(
      sonraki,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  /// İleri butonuna basıldığında önce mevcut adımın zorunlu alanlarını
  /// doğrular. Eksik varsa kullanıcıya bildirir ve geçişi engeller.
  void _ileriBasildi() {
    if (_adim == 0) {
      if (_adDenetleyici.text.trim().isEmpty) {
        _mesajGoster('Adını gir.');
        return;
      }
      if (_soyadDenetleyici.text.trim().isEmpty) {
        _mesajGoster('Soyadını gir.');
        return;
      }
      if (_cinsiyet.isEmpty) {
        _mesajGoster('Cinsiyet seç.');
        return;
      }
      if (_dogumTarihi == null) {
        _mesajGoster('Doğum tarihini seç.');
        return;
      }
    } else if (_adim == 2) {
      if (!_izinliHedefler.contains(_hedefDenetleyici.text)) {
        _mesajGoster('Fitness hedefi seç.');
        return;
      }
    }
    _adimaGit(_adim + 1);
  }

  void _hedefSec(String hedef) {
    setState(() => _hedefDenetleyici.text = hedef);
  }

  void _mesajGoster(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mesaj)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Form(
              key: _formAnahtari,
              child: Column(
                children: [
                  _Baslik(adim: _adim),
                  Expanded(
                    child: PageView(
                      controller: _sayfaDenetleyici,
                      // Kullanıcı adımları kaydırarak atlamasın; geçiş yalnızca
                      // "İleri" butonu üzerinden, doğrulamadan sonra gerçekleşir.
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (value) => setState(() => _adim = value),
                      children: [
                        _KimlikAdimi(
                          adDenetleyici: _adDenetleyici,
                          soyadDenetleyici: _soyadDenetleyici,
                          cinsiyet: _cinsiyet,
                          dogumTarihi: _dogumTarihi,
                          cinsiyetDegisti: (value) =>
                              setState(() => _cinsiyet = value),
                          dogumTarihiSecildi: _dogumTarihiSec,
                        ),
                        _BiyometriAdimi(
                          boyDenetleyici: _boyDenetleyici,
                          kiloDenetleyici: _kiloDenetleyici,
                        ),
                        _HedefAdimi(
                          hedefKiloDenetleyici: _hedefKiloDenetleyici,
                          hedefDenetleyici: _hedefDenetleyici,
                          hedefSecildi: _hedefSec,
                        ),
                        _OzetAdimi(
                          boyDenetleyici: _boyDenetleyici,
                          kiloDenetleyici: _kiloDenetleyici,
                          hedefKiloDenetleyici: _hedefKiloDenetleyici,
                          hedefDenetleyici: _hedefDenetleyici,
                        ),
                      ],
                    ),
                  ),
                  _AltBolum(
                    adim: _adim,
                    kaydediliyor: _kaydediliyor,
                    geriBasildi: () => _adimaGit(_adim - 1),
                    ileriBasildi: _ileriBasildi,
                    kaydetBasildi: _kaydet,
                  ),
                ],
              ),
            ),
          ),
          if (_kaydediliyor)
            const OturumYuklemeKatmani(
              title: 'Profilin kaydediliyor',
              subtitle: 'Hedeflerin senkronize ediliyor',
            ),
        ],
      ),
    );
  }
}

/// Ekranın üst kısmı: başlık, adım sayacı (ör. 2/4) ve ilerleme çubuğu.
class _Baslik extends StatelessWidget {
  final int adim;

  const _Baslik({required this.adim});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: UygulamaTemasi.anaRenk.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.fitness_center,
                  color: UygulamaTemasi.anaRenk,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Profil Kurulumu',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '${adim + 1}/4',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LinearProgressIndicator(
            value: (adim + 1) / 4,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: Colors.white.withValues(alpha: 0.08),
          ),
        ],
      ),
    );
  }
}

/// 1. adım: ad, soyad, cinsiyet ve doğum tarihinin alındığı kimlik adımı.
class _KimlikAdimi extends StatelessWidget {
  final TextEditingController adDenetleyici;
  final TextEditingController soyadDenetleyici;
  final String cinsiyet;
  final DateTime? dogumTarihi;
  final ValueChanged<String> cinsiyetDegisti;
  final VoidCallback dogumTarihiSecildi;

  const _KimlikAdimi({
    required this.adDenetleyici,
    required this.soyadDenetleyici,
    required this.cinsiyet,
    required this.dogumTarihi,
    required this.cinsiyetDegisti,
    required this.dogumTarihiSecildi,
  });

  @override
  Widget build(BuildContext context) {
    return _AdimKabugu(
      icon: Icons.person_outline,
      title: 'Seni tanıyalım',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ad/Soyad opsiyonel; Google ile giriş yapıldıysa dolu gelir.
          Row(
            children: [
              Expanded(
                child: _MetinAlani(
                  controller: adDenetleyici,
                  label: 'Ad',
                  textCapitalization: TextCapitalization.words,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetinAlani(
                  controller: soyadDenetleyici,
                  label: 'Soyad',
                  textCapitalization: TextCapitalization.words,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Cinsiyet zorunlu; varsayılan seçim yok. Kullanıcı Erkek veya
          // Kadın'ı açıkça seçmeli. "Belirtmem" ilk kurulumda kabul edilmiyor.
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'E', label: Text('Erkek')),
              ButtonSegment(value: 'K', label: Text('Kadın')),
            ],
            selected: cinsiyet.isEmpty ? <String>{} : {cinsiyet},
            emptySelectionAllowed: true,
            onSelectionChanged: (values) {
              if (values.isEmpty) return;
              cinsiyetDegisti(values.first);
            },
          ),
          const SizedBox(height: 18),
          InkWell(
            onTap: dogumTarihiSecildi,
            borderRadius: BorderRadius.circular(8),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Doğum tarihi',
                prefixIcon: Icon(Icons.cake_outlined),
                border: OutlineInputBorder(),
              ),
              child: Text(
                dogumTarihi == null
                    ? 'Tarih seç'
                    : _tarihFormatla(dogumTarihi!),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 2. adım: boy ve kilo ölçümlerinin alındığı adım.
class _BiyometriAdimi extends StatelessWidget {
  final TextEditingController boyDenetleyici;
  final TextEditingController kiloDenetleyici;

  const _BiyometriAdimi({
    required this.boyDenetleyici,
    required this.kiloDenetleyici,
  });

  @override
  Widget build(BuildContext context) {
    return _AdimKabugu(
      icon: Icons.monitor_weight_outlined,
      title: 'Ölçümlerini ekle',
      child: Row(
        children: [
          Expanded(
            child: _SayiAlani(
              controller: boyDenetleyici,
              label: 'Boy',
              suffix: 'cm',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SayiAlani(
              controller: kiloDenetleyici,
              label: 'Kilo',
              suffix: 'kg',
            ),
          ),
        ],
      ),
    );
  }
}

/// 3. adım: hedef kilo ve fitness hedefinin seçildiği adım.
class _HedefAdimi extends StatelessWidget {
  final TextEditingController hedefKiloDenetleyici;
  final TextEditingController hedefDenetleyici;
  final ValueChanged<String> hedefSecildi;

  const _HedefAdimi({
    required this.hedefKiloDenetleyici,
    required this.hedefDenetleyici,
    required this.hedefSecildi,
  });

  @override
  Widget build(BuildContext context) {
    // Serbest metin yok: kullanıcı Yağ kaybı / Kas kazanımı / Kondisyon ve
    // genel sağlık seçimlerinden BİRİNİ yapmalı. Stringler API'deki
    // ONBOARDING_GOAL_CHOICES ile birebir aynı.
    final seciliHedef = hedefDenetleyici.text;
    return _AdimKabugu(
      icon: Icons.flag_outlined,
      title: 'Hedefini seç',
      child: Column(
        children: [
          _SayiAlani(
            controller: hedefKiloDenetleyici,
            label: 'Hedef kilo',
            suffix: 'kg',
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Fitness hedefi',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (final hedef in onboardingGoalChoices)
            _HedefKarti(
              title: hedef,
              icon: _iconForGoal(hedef),
              selected: seciliHedef == hedef,
              onTap: () => hedefSecildi(hedef),
            ),
        ],
      ),
    );
  }

  static IconData _iconForGoal(String hedef) {
    switch (hedef) {
      case 'Yağ kaybı':
        return Icons.local_fire_department_outlined;
      case 'Kas kazanımı':
        return Icons.bolt_outlined;
      case 'Kondisyon ve genel sağlık':
        return Icons.favorite_border;
      default:
        return Icons.flag_outlined;
    }
  }
}

/// 4. adım: girilen tüm bilgilerin kaydetmeden önce gözden geçirildiği özet.
class _OzetAdimi extends StatelessWidget {
  final TextEditingController boyDenetleyici;
  final TextEditingController kiloDenetleyici;
  final TextEditingController hedefKiloDenetleyici;
  final TextEditingController hedefDenetleyici;

  const _OzetAdimi({
    required this.boyDenetleyici,
    required this.kiloDenetleyici,
    required this.hedefKiloDenetleyici,
    required this.hedefDenetleyici,
  });

  @override
  Widget build(BuildContext context) {
    return _AdimKabugu(
      icon: Icons.check_circle_outline,
      title: 'Hazırsın',
      child: Column(
        children: [
          _OzetSatiri(label: 'Boy', value: '${boyDenetleyici.text} cm'),
          _OzetSatiri(label: 'Kilo', value: '${kiloDenetleyici.text} kg'),
          _OzetSatiri(
            label: 'Hedef kilo',
            value: '${hedefKiloDenetleyici.text} kg',
          ),
          _OzetSatiri(label: 'Hedef', value: hedefDenetleyici.text),
        ],
      ),
    );
  }
}

class _AdimKabugu extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _AdimKabugu({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        Icon(icon, color: UygulamaTemasi.anaRenk, size: 44),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 22),
        child,
      ],
    );
  }
}

class _SayiAlani extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String suffix;

  const _SayiAlani({
    required this.controller,
    required this.label,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        final cozulmus = _ondalikSayiyaCevir(value ?? '');
        if (cozulmus == null || cozulmus <= 0) return '$label gerekli';
        return null;
      },
    );
  }
}

class _MetinAlani extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextCapitalization textCapitalization;

  const _MetinAlani({
    required this.controller,
    required this.label,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _HedefKarti extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _HedefKarti({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? UygulamaTemasi.anaRenk.withValues(alpha: 0.16)
                : UygulamaTemasi.yuzey,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? UygulamaTemasi.anaRenk
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: UygulamaTemasi.anaRenk),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, color: UygulamaTemasi.anaRenk),
            ],
          ),
        ),
      ),
    );
  }
}

class _OzetSatiri extends StatelessWidget {
  final String label;
  final String value;

  const _OzetSatiri({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: UygulamaTemasi.yuzey,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.62)),
            ),
          ),
          Flexible(
            child: Text(
              value.isEmpty ? '-' : value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ekranın alt kısmı: "Geri" ve "İleri / Hadi Başlayalım" gezinme butonları.
class _AltBolum extends StatelessWidget {
  final int adim;
  final bool kaydediliyor;
  final VoidCallback geriBasildi;
  final VoidCallback ileriBasildi;
  final VoidCallback kaydetBasildi;

  const _AltBolum({
    required this.adim,
    required this.kaydediliyor,
    required this.geriBasildi,
    required this.ileriBasildi,
    required this.kaydetBasildi,
  });

  @override
  Widget build(BuildContext context) {
    final sonAdimMi = adim == 3;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: adim == 0 || kaydediliyor ? null : geriBasildi,
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: kaydediliyor
                  ? null
                  : (sonAdimMi ? kaydetBasildi : ileriBasildi),
              icon: kaydediliyor
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(sonAdimMi ? Icons.check : Icons.arrow_forward),
              label: Text(sonAdimMi ? 'Hadi Başlayalım' : 'İleri'),
            ),
          ),
        ],
      ),
    );
  }
}

String _sayiFormatla(double? value) {
  if (value == null) return '';
  if (value % 1 == 0) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}

String _tarihFormatla(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}

double? _ondalikSayiyaCevir(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}
