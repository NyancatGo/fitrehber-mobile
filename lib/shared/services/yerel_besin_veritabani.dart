// ---------------------------------------------------------------------------
// YEREL BESİN VERİTABANI SERVİSİ
// ---------------------------------------------------------------------------
// Uygulamayla birlikte gelen iki JSON dosyasından (genel besinler + Türkiye
// markalı ürünler) besin araması yapar. Veri uygulama açılışında bir kez
// belleğe yüklenir; böylece tüm aramalar internet gerektirmeden, anında çalışır.
// ---------------------------------------------------------------------------

import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;

/// Yerel JSON veritabanından besin araması yapan servis.
/// Uygulama başlatıldığında dosya bir kez okunup bellekte tutulur.
/// Tüm aramalar offline (milisaniye düzeyinde) gerçekleşir.
class YerelBesinVeritabani {
  YerelBesinVeritabani._();
  static final instance = YerelBesinVeritabani._();

  List<YerelBesin>? _besinler;
  List<YerelBesin>? _siraliBesinler;
  Future<void>? _hazirlaniyor;

  /// Veritabanını bellekte hazırlar. İki kaynak yüklenir:
  ///   - foods_cleaned.json   → generic foods (curated)
  ///   - foods_brands_tr.json → Türkiye'deki markalı ürünler (OpenFoodFacts)
  /// İkincisi yoksa veya bozuksa sadece birincisi kullanılır.
  Future<void> hazirla() async {
    if (_besinler != null) return;
    final devamEdenHazirlik = _hazirlaniyor;
    if (devamEdenHazirlik != null) return devamEdenHazirlik;

    _hazirlaniyor = _tumunuYukle();
    return _hazirlaniyor!;
  }

  Future<void> _tumunuYukle() async {
    try {
      final genel = await _dosyaYukle('assets/data/foods_cleaned.json');
      final markali = await _dosyaYukle('assets/data/foods_brands_tr.json');
      _besinler = [
        ...genel,
        ...markali,
      ].where((f) => f.kalori100g > 0).toList();
      _siraliBesinler = List<YerelBesin>.from(_besinler!)
        ..sort((a, b) => a.isim.compareTo(b.isim));
    } catch (e) {
      _besinler = [];
      _siraliBesinler = [];
    } finally {
      _hazirlaniyor = null;
    }
  }

  /// Tek bir JSON dosyasını yükler; bulunamazsa veya bozuksa boş liste döner.
  Future<List<YerelBesin>> _dosyaYukle(String assetYolu) async {
    try {
      final jsonMetni = await rootBundle.loadString(assetYolu);
      return compute(_besinleriCoz, jsonMetni);
    } catch (_) {
      return const [];
    }
  }

  /// Tüm yüklü besinlerin sayısını döner.
  int get toplamSayi => _besinler?.length ?? 0;

  /// Besin arar. Türkçe isim ve İngilizce isimde aynı anda arar.
  /// Sonuçlar alakalılık sırasına göre sıralanır (tam eşleşme > başlangıç > içerik).
  List<YerelBesin> ara(String sorgu, {int sinir = 120}) {
    final besinler = _besinler;
    if (besinler == null || sorgu.trim().isEmpty) return [];

    final q = _turkceKucult(sorgu.trim());
    final kelimeler = q.split(RegExp(r'\s+'));

    final sonuclar = <_PuanliBesin>[];

    for (final besin in besinler) {
      final ad = besin.aramaAdi;
      final ingilizceAd = besin.aramaIngilizceAdi;
      final marka = besin.aramaMarkasi;
      final blob = besin.aramaMetni;

      int puan = 0;

      // Tam eşleşme (en yüksek puan)
      if (ad == q) {
        puan = 100;
      }
      // Başlangıçla eşleşme
      else if (ad.startsWith(q)) {
        puan = 80;
      }
      // Marka başlangıcı
      else if (marka.startsWith(q)) {
        puan = 70;
      }
      // İçerik eşleşmesi
      else if (ad.contains(q)) {
        puan = 60;
      }
      // Marka içeriği
      else if (marka.contains(q)) {
        puan = 50;
      }
      // Kelime bazında arama (her kelime besinin isminde geçiyorsa)
      else if (kelimeler.every(blob.contains)) {
        puan = 40;
      }
      // İngilizce isimde arama
      else if (ingilizceAd.contains(q)) {
        puan = 20;
      }

      if (puan > 0) {
        sonuclar.add(_PuanliBesin(besin, puan));
      }
    }

    // Skora göre azalan, sonra isme göre alfabetik sırala
    sonuclar.sort((a, b) {
      final cmp = b.puan.compareTo(a.puan);
      if (cmp != 0) return cmp;
      return a.besin.isim.compareTo(b.besin.isim);
    });

    return sonuclar.take(sinir).map((s) => s.besin).toList();
  }

  /// Arama boşken gösterilecek varsayılan liste.
  /// Tam veri bellekte kalır; ilk ekranda yalnızca sınırlı ve cache'li alfabetik
  /// liste döndürülür. Kullanıcı yazdıkça tüm veri üzerinde arama yapılır.
  List<YerelBesin> tumunuGetir({int sinir = 150}) {
    final besinler = _siraliBesinler;
    if (besinler == null) return [];
    return besinler.take(sinir).toList();
  }

  /// Türkçe küçük harf dönüşümü (İ->i, I->ı gibi).
  static String _turkceKucult(String s) {
    return s
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .replaceAll('Ğ', 'ğ')
        .replaceAll('Ü', 'ü')
        .replaceAll('Ş', 'ş')
        .replaceAll('Ö', 'ö')
        .replaceAll('Ç', 'ç')
        .toLowerCase();
  }
}

List<YerelBesin> _besinleriCoz(String jsonMetni) {
  final list = json.decode(jsonMetni) as List<dynamic>;
  return list
      .whereType<Map>()
      .map((item) => YerelBesin.fromJson(Map<String, dynamic>.from(item)))
      .toList();
}

class _PuanliBesin {
  final YerelBesin besin;
  final int puan;
  _PuanliBesin(this.besin, this.puan);
}

/// Yerel JSON'dan okunan tek bir besin maddesi.
class YerelBesin {
  final String id;
  final String isim;
  final String isimIngilizce;
  final String marka; // OFF kaynağı için marka adı; generic foods'ta boş.
  final String aramaAdi;
  final String aramaIngilizceAdi;
  final String aramaMarkasi;
  final String aramaMetni;

  // Makrolar (100g başına)
  final double kalori100g;
  final double protein100g;
  final double karbonhidrat100g;
  final double yag100g;

  // Mikro besinler (100g başına)
  final double sodyum100g;
  final double potasyum100g;
  final double kolesterol100g;
  final double lif100g;
  final double seker100g;
  final double doymusYag100g;

  final bool dogrulanmisMi;

  const YerelBesin({
    required this.id,
    required this.isim,
    required this.isimIngilizce,
    this.marka = '',
    required this.aramaAdi,
    required this.aramaIngilizceAdi,
    required this.aramaMarkasi,
    required this.aramaMetni,
    required this.kalori100g,
    required this.protein100g,
    required this.karbonhidrat100g,
    required this.yag100g,
    required this.sodyum100g,
    required this.potasyum100g,
    required this.kolesterol100g,
    required this.lif100g,
    required this.seker100g,
    required this.doymusYag100g,
    required this.dogrulanmisMi,
  });

  factory YerelBesin.fromJson(Map<String, dynamic> json) {
    final isim = (json['isim'] ?? '').toString().trim();
    final isimIngilizce = (json['isim_ingilizce'] ?? '').toString().trim();
    final marka = (json['brand'] ?? '').toString().trim();
    final aramaAdi = YerelBesinVeritabani._turkceKucult(isim);
    final aramaIngilizceAdi = YerelBesinVeritabani._turkceKucult(isimIngilizce);
    final aramaMarkasi = YerelBesinVeritabani._turkceKucult(marka);

    return YerelBesin(
      id: (json['id'] ?? '').toString(),
      isim: isim,
      isimIngilizce: isimIngilizce,
      marka: marka,
      aramaAdi: aramaAdi,
      aramaIngilizceAdi: aramaIngilizceAdi,
      aramaMarkasi: aramaMarkasi,
      aramaMetni: '$aramaAdi $aramaIngilizceAdi $aramaMarkasi',
      kalori100g: _d(json['kalori100g']),
      protein100g: _d(json['protein100g']),
      karbonhidrat100g: _d(json['karbonhidrat100g']),
      yag100g: _d(json['yag100g']),
      sodyum100g: _d(json['sodyum100g']),
      potasyum100g: _d(json['potasyum100g']),
      kolesterol100g: _d(json['kolesterol100g']),
      lif100g: _d(json['lif100g']),
      seker100g: _d(json['seker100g']),
      doymusYag100g: _d(json['doymus_yag100g']),
      dogrulanmisMi: json['isVerified'] as bool? ?? false,
    );
  }

  /// Gramaja göre hesaplanmış kaloriyi döner.
  double gramKalori(double gram) => (kalori100g * gram) / 100;
  double gramProtein(double gram) => (protein100g * gram) / 100;
  double gramKarbonhidrat(double gram) => (karbonhidrat100g * gram) / 100;
  double gramYag(double gram) => (yag100g * gram) / 100;
  double gramSodyum(double gram) => (sodyum100g * gram) / 100;
  double gramPotasyum(double gram) => (potasyum100g * gram) / 100;
  double gramKolesterol(double gram) => (kolesterol100g * gram) / 100;
  double gramLif(double gram) => (lif100g * gram) / 100;
  double gramSeker(double gram) => (seker100g * gram) / 100;
  double gramDoymusYag(double gram) => (doymusYag100g * gram) / 100;

  static double _d(Object? v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0.0;
  }
}
