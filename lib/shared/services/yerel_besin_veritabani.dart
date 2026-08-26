// ---------------------------------------------------------------------------
// YEREL BESİN VERİTABANI SERVİSİ
// ---------------------------------------------------------------------------
// Sunucudan senkronlanmış besin önbelleği üzerinde arama yapar. Önbellek bir kez
// belleğe yüklenir; böylece tüm aramalar internet gerektirmeden, anında çalışır.
//
// TEK KAYNAK: sunucudaki `posts_besin` tablosu. Uygulamayla birlikte gelen
// bundled JSON seed KALDIRILDI — çünkü seed'den seçilen besin gerçek `besin_id`
// taşımıyordu ve öğün kaydı custom-food yoluna düşüyordu (porsiyon desteği yok,
// makrolar istemcide hesaplanıyor, kayıt besin veritabanından kalıcı kopuk).
// Önbellek boşsa arama yapılmaz; `BesinSenkronServisi` ile ilk senkron beklenir.
// ---------------------------------------------------------------------------

import 'dart:convert';

import 'package:flutter/foundation.dart' show compute, visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/beslenme_model.dart';

/// Senkron önbelleğinden besin araması yapan servis.
/// Önbellek bir kez okunup bellekte tutulur; aramalar offline (milisaniye
/// düzeyinde) gerçekleşir.
class YerelBesinVeritabani {
  YerelBesinVeritabani._();
  static final instance = YerelBesinVeritabani._();

  // Senkron cache anahtarlari (BesinSenkronServisi de ayni anahtarlari yazar).
  /// Sunucudan senkronlanmis besin listesi (JSON dizisi).
  static const String cacheKey = 'besin_cache_v2';

  /// En son senkronun sunucu zamani (bir sonraki ?since= delta icin).
  static const String lastSyncKey = 'besin_cache_last_sync';

  /// En son senkronun istemci zamani (throttle icin).
  static const String lastSyncAtKey = 'besin_cache_synced_at';

  List<YerelBesin>? _besinler;
  List<YerelBesin>? _siraliBesinler;
  Future<void>? _hazirlaniyor;

  @visibleForTesting
  void resetForTests() {
    _besinler = null;
    _siraliBesinler = null;
    _hazirlaniyor = null;
  }

  /// Veritabanını bellekte hazırlar. Kaynak yalnızca senkron önbelleğidir;
  /// önbellek yoksa bellek boş kalır ve [hazirMi] false döner (çağıran taraf
  /// `BesinSenkronServisi.senkronEt` ile ilk senkronu tetiklemelidir).
  Future<void> hazirla() async {
    if (_besinler != null) return;
    final devamEdenHazirlik = _hazirlaniyor;
    if (devamEdenHazirlik != null) return devamEdenHazirlik;

    _hazirlaniyor = _tumunuYukle();
    return _hazirlaniyor!;
  }

  /// Arama yapılabilecek kadar veri bellekte mi? İlk senkron tamamlanmadan
  /// (veya önbellek temizlenmişse) false döner.
  bool get hazirMi => (_besinler?.isNotEmpty ?? false);

  Future<void> _tumunuYukle() async {
    try {
      final cached = await _cachetenOku();
      _kur(cached ?? const []);
    } catch (e) {
      _besinler = [];
      _siraliBesinler = [];
    } finally {
      _hazirlaniyor = null;
    }
  }

  /// Verilen besin listesini bellege kurar (kalorisizleri eler, alfabetik siralar).
  /// `besinId <= 0` olan kayit sunucu PK'si tasimadigi icin elenir — bu kayittan
  /// ogun eklenirse custom-food yoluna duserdi (bkz. dosya basligi).
  void _kur(List<YerelBesin> besinler) {
    _besinler = besinler
        .where(
          (f) =>
              f.besinId > 0 &&
              f.kalori100g > 0 &&
              f.qualityStatus != 'rejected',
        )
        .toList();
    _siraliBesinler = List<YerelBesin>.from(_besinler!)..sort(_besinSirala);
  }

  /// Senkron sonrasi (BesinSenkronServisi) bellegi taze cache verisiyle tazeler.
  void cachetenYukle(List<Map<String, dynamic>> foods) {
    _kur(foods.map((m) => YerelBesin.fromCache(m)).toList());
  }

  /// SharedPreferences'taki senkron cache'ini okur; yoksa/bozuksa null.
  Future<List<YerelBesin>?> _cachetenOku() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(cacheKey);
      if (raw == null || raw.isEmpty) return null;
      return compute(_cacheCoz, raw);
    } catch (_) {
      return null;
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
      if (a.besin.dogrulanmisMi != b.besin.dogrulanmisMi) {
        return a.besin.dogrulanmisMi ? -1 : 1;
      }
      final kalite = b.besin.qualityScore.compareTo(a.besin.qualityScore);
      if (kalite != 0) return kalite;
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

  /// Arama anahtari uretir: once Turkce kucuk harf, sonra ASCII katlama.
  ///
  /// Iki asama ayri ayri gerekli:
  ///   1. Buyuk harf esleme (İ->i, I->ı) — Dart'in `toLowerCase()`'i Unicode
  ///      varsayilanini kullanir, 'İ' icin 'i' + birlesik nokta uretir. Bu
  ///      esleme once yapilmazsa anahtarin icinde gorunmez bir karakter kalir.
  ///   2. ASCII katlama (ı->i, ğ->g, ...) — kullanici mobil klavyede Turkce
  ///      karakter yazmiyor: "gogsu", "corba", "cikolata". Katlama olmadan bu
  ///      sorgular hicbir seye eslesmiyordu.
  ///
  /// Hem sorgu hem de indeks (bkz. [YerelBesin.fromCache]) bu fonksiyondan
  /// gectigi icin iki taraf her zaman ayni alfabede kalir. Sunucudaki
  /// `normalize_food_text` ile ayni sonucu uretmesi GEREKMEZ — karsilastirma
  /// daima istemci icinde, kendi urettigi anahtarlar arasinda yapilir.
  static String _turkceKucult(String s) {
    final kucuk = s
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .replaceAll('Ğ', 'ğ')
        .replaceAll('Ü', 'ü')
        .replaceAll('Ş', 'ş')
        .replaceAll('Ö', 'ö')
        .replaceAll('Ç', 'ç')
        .toLowerCase();
    return kucuk
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');
  }
}

/// Senkron cache JSON'unu (sunucu formati) cozer — compute izolatinda calisir.
List<YerelBesin> _cacheCoz(String jsonMetni) {
  final list = json.decode(jsonMetni) as List<dynamic>;
  return list
      .whereType<Map>()
      .map((item) => YerelBesin.fromCache(Map<String, dynamic>.from(item)))
      .toList();
}

class _PuanliBesin {
  final YerelBesin besin;
  final int puan;
  _PuanliBesin(this.besin, this.puan);
}

/// Senkron onbelleginden okunan tek bir besin maddesi.
class YerelBesin {
  final String id;

  /// Sunucudaki Besin PK'si — her zaman dolu. Ogun eklerken `besin_id` olarak
  /// gonderilir; makrolari sunucu kendi tablosundan hesaplar (web ile birebir
  /// tutarli, porsiyon destekli, sonradan duzeltilebilir kayit).
  final int besinId;
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
  final int qualityScore;
  final String qualityStatus;
  final String sourceType;
  final List<String> aliases;

  /// Bu besine ait porsiyon birimleri.
  final List<BesinPorsiyonModel> porsiyonlar;

  const YerelBesin({
    required this.id,
    required this.besinId,
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
    this.qualityScore = 0,
    this.qualityStatus = 'needs_review',
    this.sourceType = 'manual',
    this.aliases = const [],
    this.porsiyonlar = const [],
  });

  /// Sunucudan senkronlanmis besin kaydindan olusturur (BesinSyncSerializer).
  /// Server PK'si `id` -> [besinId]; `kaynak_id` yerel [id] olarak tutulur.
  factory YerelBesin.fromCache(Map<String, dynamic> json) {
    final isim = (json['isim'] ?? '').toString().trim();
    final isimIngilizce = (json['isim_ingilizce'] ?? '').toString().trim();
    final marka = (json['marka'] ?? '').toString().trim();
    final aramaAdi = YerelBesinVeritabani._turkceKucult(isim);
    final aramaIngilizceAdi = YerelBesinVeritabani._turkceKucult(isimIngilizce);
    final aramaMarkasi = YerelBesinVeritabani._turkceKucult(marka);
    final aliases = _stringList(json['aliases']);
    final aramaAliaslari = aliases
        .map(YerelBesinVeritabani._turkceKucult)
        .join(' ');

    var pList = <BesinPorsiyonModel>[];
    if (json['porsiyonlar'] is List) {
      pList =
          (json['porsiyonlar'] as List)
              .whereType<Map<String, dynamic>>()
              .map((item) => BesinPorsiyonModel.fromJson(item))
              .toList()
            ..sort(_porsiyonSirala);
    }

    return YerelBesin(
      id: (json['kaynak_id'] ?? '').toString(),
      // PK yoksa 0 kalir; _kur() bu kayitlari eler.
      besinId: (json['id'] as num?)?.toInt() ?? 0,
      isim: isim,
      isimIngilizce: isimIngilizce,
      marka: marka,
      aramaAdi: aramaAdi,
      aramaIngilizceAdi: aramaIngilizceAdi,
      aramaMarkasi: aramaMarkasi,
      aramaMetni: '$aramaAdi $aramaIngilizceAdi $aramaMarkasi $aramaAliaslari',
      kalori100g: _d(json['kalori_100g']),
      protein100g: _d(json['protein_100g']),
      karbonhidrat100g: _d(json['karbonhidrat_100g']),
      yag100g: _d(json['yag_100g']),
      sodyum100g: _d(json['sodyum_100g']),
      potasyum100g: _d(json['potasyum_100g']),
      kolesterol100g: _d(json['kolesterol_100g']),
      lif100g: _d(json['lif_100g']),
      seker100g: _d(json['seker_100g']),
      doymusYag100g: _d(json['doymus_yag_100g']),
      dogrulanmisMi: json['is_verified'] as bool? ?? false,
      qualityScore: _i(json['quality_score']),
      qualityStatus: (json['quality_status'] ?? 'needs_review').toString(),
      sourceType: (json['source_type'] ?? 'manual').toString(),
      aliases: aliases,
      porsiyonlar: pList,
    );
  }

  factory YerelBesin.fromBesinModel(BesinModel model) {
    final isim = model.isim.trim();
    final marka = (model.marka ?? '').trim();
    final aramaAdi = YerelBesinVeritabani._turkceKucult(isim);
    final aramaMarkasi = YerelBesinVeritabani._turkceKucult(marka);
    final aramaAliaslari = model.aliases
        .map(YerelBesinVeritabani._turkceKucult)
        .join(' ');

    return YerelBesin(
      id: model.barkod ?? 'server:${model.id}',
      besinId: model.id,
      isim: isim,
      isimIngilizce: '',
      marka: marka,
      aramaAdi: aramaAdi,
      aramaIngilizceAdi: '',
      aramaMarkasi: aramaMarkasi,
      aramaMetni: '$aramaAdi $aramaMarkasi $aramaAliaslari',
      kalori100g: model.kalori100g.toDouble(),
      protein100g: model.protein100g,
      karbonhidrat100g: model.karbonhidrat100g,
      yag100g: model.yag100g,
      sodyum100g: 0,
      potasyum100g: 0,
      kolesterol100g: 0,
      lif100g: 0,
      seker100g: 0,
      doymusYag100g: 0,
      dogrulanmisMi: model.dogrulanmisMi,
      qualityScore: model.qualityScore,
      qualityStatus: model.qualityStatus,
      sourceType: model.sourceType,
      aliases: model.aliases,
      porsiyonlar: model.porsiyonlar,
    );
  }

  BesinPorsiyonModel? get varsayilanPorsiyon {
    if (porsiyonlar.isEmpty) return null;
    for (final porsiyon in porsiyonlar) {
      if (porsiyon.varsayilan) return porsiyon;
    }
    return porsiyonlar.first;
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

int _besinSirala(YerelBesin a, YerelBesin b) {
  if (a.dogrulanmisMi != b.dogrulanmisMi) {
    return a.dogrulanmisMi ? -1 : 1;
  }
  final kalite = b.qualityScore.compareTo(a.qualityScore);
  if (kalite != 0) return kalite;
  return a.isim.compareTo(b.isim);
}

int _porsiyonSirala(BesinPorsiyonModel a, BesinPorsiyonModel b) {
  final siraKarsilastirma = a.sira.compareTo(b.sira);
  if (siraKarsilastirma != 0) return siraKarsilastirma;
  return a.id.compareTo(b.id);
}

int _i(Object? v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

List<String> _stringList(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
