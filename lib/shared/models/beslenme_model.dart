// ---------------------------------------------------------------------------
// BESLENME MODELLERİ
// ---------------------------------------------------------------------------
// Beslenme takibi ekranının tüm veri yapıları burada toplanmıştır:
//   * BesinModel        → besin veritabanındaki bir yiyecek (100 g değerleriyle)
//   * OgunKaydiModel    → kullanıcının bir öğüne eklediği tek bir kayıt
//   * GunlukBeslenmeModel → bir günün tamamı: toplam kalori/makro + su + öğünler
// ---------------------------------------------------------------------------

/// Bir besine ait porsiyon birimini temsil eder.
class BesinPorsiyonModel {
  final int id;
  final String isim;
  final double gramEsdegeri;

  const BesinPorsiyonModel({
    required this.id,
    required this.isim,
    required this.gramEsdegeri,
  });

  factory BesinPorsiyonModel.fromJson(Map<String, dynamic> json) {
    return BesinPorsiyonModel(
      id: _parseInt(json['id']) ?? 0,
      isim: (json['isim'] ?? '').toString(),
      gramEsdegeri: _parseDouble(json['gram_esdegeri']) ?? 0.0,
    );
  }
}

/// Besin (yiyecek) veritabanındaki bir kaydı temsil eder.
///
/// Tüm besin değerleri **100 gram** referansına göre tutulur; kullanıcının
/// yediği gerçek miktara göre hesaplama ekran tarafında yapılır.
class BesinModel {
  /// Besinin benzersiz kimliği.
  final int id;

  /// Besinin adı (örn. "Tam buğday ekmeği").
  final String isim;

  /// Varsa marka adı; markasız/jenerik besinlerde `null`.
  final String? marka;

  /// Varsa ürün barkodu.
  final String? barkod;

  /// 100 gramdaki kalori (kcal).
  final int kalori100g;

  /// 100 gramdaki protein (g).
  final double protein100g;

  /// 100 gramdaki karbonhidrat (g).
  final double karbonhidrat100g;

  /// 100 gramdaki yağ (g).
  final double yag100g;

  /// Besinin editörlerce doğrulanıp doğrulanmadığı (güvenilirlik rozeti).
  final bool dogrulanmisMi;

  /// Bu besine ait porsiyon birimleri.
  final List<BesinPorsiyonModel> porsiyonlar;

  const BesinModel({
    required this.id,
    required this.isim,
    this.marka,
    this.barkod,
    required this.kalori100g,
    required this.protein100g,
    required this.karbonhidrat100g,
    required this.yag100g,
    required this.dogrulanmisMi,
    this.porsiyonlar = const [],
  });

  /// API'den gelen JSON'u `BesinModel`e dönüştürür.
  factory BesinModel.fromJson(Map<String, dynamic> json) {
    var pList = <BesinPorsiyonModel>[];
    if (json['porsiyonlar'] is List) {
      pList = (json['porsiyonlar'] as List)
          .whereType<Map<String, dynamic>>()
          .map((item) => BesinPorsiyonModel.fromJson(item))
          .toList();
    }
    return BesinModel(
      id: _parseInt(json['id']) ?? 0,
      isim: (json['isim'] ?? '').toString(),
      marka: json['marka']?.toString(),
      barkod: json['barkod']?.toString(),
      kalori100g: _parseInt(json['kalori_100g']) ?? 0,
      protein100g: _parseDouble(json['protein_100g']) ?? 0.0,
      karbonhidrat100g: _parseDouble(json['karbonhidrat_100g']) ?? 0.0,
      yag100g: _parseDouble(json['yag_100g']) ?? 0.0,
      dogrulanmisMi: json['is_verified'] as bool? ?? false,
      porsiyonlar: pList,
    );
  }
}

/// Kullanıcının belirli bir öğüne eklediği tek bir besin kaydını temsil eder.
///
/// `BesinModel`den farkı: buradaki kalori/makro değerleri **gerçekten yenen
/// miktara göre** hesaplanmış nihai değerlerdir.
class OgunKaydiModel {
  /// Kaydın benzersiz kimliği (silme/güncelleme için kullanılır).
  final int id;

  /// Kaydın ait olduğu tarih (ISO biçiminde).
  final String tarih;

  /// Öğün tipi: `sabah`, `ogle`, `aksam` veya `atistirmalik`.
  final String ogunTipi;

  /// İlgili besinin kimliği (serbest girişlerde `null` olabilir).
  final int? besinId;

  /// Kayıtta görünen besin adı.
  final String besinIsim;

  /// Yenen miktar.
  final double miktar;

  /// Miktarın birimi (örn. "g", "porsiyon").
  final String miktarBirimi;

  /// Bu kaydın toplam kalorisi (kcal).
  final int kalori;

  /// Bu kaydın toplam proteini (g).
  final double protein;

  /// Bu kaydın toplam karbonhidratı (g).
  final double karbonhidrat;

  /// Bu kaydın toplam yağı (g).
  final double yag;

  /// Varsa bu kayıtta kullanılan porsiyon birimi.
  final BesinPorsiyonModel? porsiyon;

  const OgunKaydiModel({
    required this.id,
    required this.tarih,
    required this.ogunTipi,
    this.besinId,
    required this.besinIsim,
    required this.miktar,
    required this.miktarBirimi,
    required this.kalori,
    required this.protein,
    required this.karbonhidrat,
    required this.yag,
    this.porsiyon,
  });

  /// API'den gelen JSON'u `OgunKaydiModel`e dönüştürür.
  factory OgunKaydiModel.fromJson(Map<String, dynamic> json) {
    return OgunKaydiModel(
      id: _parseInt(json['id']) ?? 0,
      tarih: (json['tarih'] ?? '').toString(),
      ogunTipi: (json['ogun_tipi'] ?? '').toString(),
      besinId: _parseInt(json['besin_id'] ?? json['besin']),
      besinIsim: (json['besin_isim'] ?? '').toString(),
      miktar: _parseDouble(json['miktar']) ?? 0.0,
      miktarBirimi: (json['miktar_birimi'] ?? 'g').toString(),
      kalori: _parseInt(json['kalori']) ?? 0,
      protein: _parseDouble(json['protein']) ?? 0.0,
      karbonhidrat: _parseDouble(json['karbonhidrat']) ?? 0.0,
      yag: _parseDouble(json['yag']) ?? 0.0,
      porsiyon: json['porsiyon'] != null ? BesinPorsiyonModel.fromJson(Map<String, dynamic>.from(json['porsiyon'])) : null,
    );
  }
}

/// Bir günün tüm beslenme özetini temsil eder: toplam kalori/makrolar,
/// içilen su ve öğünlere göre gruplanmış besin kayıtları.
class GunlukBeslenmeModel {
  /// Günün tarihi (ISO biçiminde).
  final String tarih;

  /// O gün içilen toplam su (ml).
  final int suMl;

  /// O gün alınan toplam kalori (kcal).
  final int kaloriKcal;

  /// O gün alınan toplam protein (g).
  final double proteinG;

  /// O gün alınan toplam karbonhidrat (g).
  final double karbonhidratG;

  /// O gün alınan toplam yağ (g).
  final double yagG;

  /// Öğün tipine göre gruplanmış besin kayıtları.
  /// Anahtarlar: `sabah`, `ogle`, `aksam`, `atistirmalik`.
  final Map<String, List<OgunKaydiModel>> ogunler;

  // --- Varsayılan günlük hedefler ------------------------------------------
  // İlerleme çubukları bu hedeflere göre doluluk oranını hesaplar.

  /// Varsayılan günlük su hedefi (ml).
  static const int gunlukSuHedefMl = 2500;

  /// Varsayılan günlük kalori hedefi (kcal).
  static const int gunlukKaloriHedef = 2000;

  /// Varsayılan günlük protein hedefi (g).
  static const double gunlukProteinHedefG = 150;

  /// Varsayılan günlük karbonhidrat hedefi (g).
  static const double gunlukKarbonhidratHedefG = 250;

  /// Varsayılan günlük yağ hedefi (g).
  static const double gunlukYagHedefG = 65;

  const GunlukBeslenmeModel({
    required this.tarih,
    this.suMl = 0,
    this.kaloriKcal = 0,
    this.proteinG = 0.0,
    this.karbonhidratG = 0.0,
    this.yagG = 0.0,
    this.ogunler = const {
      'sabah': <OgunKaydiModel>[],
      'ogle': <OgunKaydiModel>[],
      'aksam': <OgunKaydiModel>[],
      'atistirmalik': <OgunKaydiModel>[],
    },
  });

  /// API'den gelen JSON'u `GunlukBeslenmeModel`e dönüştürür.
  factory GunlukBeslenmeModel.fromJson(Map<String, dynamic> json) {
    final ogunlerJson = json['ogunler'] as Map<String, dynamic>? ?? {};

    // Dört öğün anahtarını her zaman hazır bulunduralım ki ekran tarafında
    // "anahtar yok" kontrolü yapmak gerekmesin.
    final parsedOgunler = <String, List<OgunKaydiModel>>{
      'sabah': [],
      'ogle': [],
      'aksam': [],
      'atistirmalik': [],
    };

    ogunlerJson.forEach((key, value) {
      if (value is List) {
        parsedOgunler[key] = value
            .whereType<Map>()
            .map(
              (item) =>
                  OgunKaydiModel.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      }
    });

    return GunlukBeslenmeModel(
      tarih: (json['tarih'] ?? '').toString(),
      suMl: _parseInt(json['su_ml']) ?? 0,
      // Backend bazen `toplam_*`, bazen `*_g` anahtarlarını kullandığı için
      // her iki olasılık da denenir.
      kaloriKcal: _parseInt(json['toplam_kalori'] ?? json['kalori_kcal']) ?? 0,
      proteinG:
          _parseDouble(json['toplam_protein'] ?? json['protein_g']) ?? 0.0,
      karbonhidratG:
          _parseDouble(json['toplam_karbonhidrat'] ?? json['karbonhidrat_g']) ??
          0.0,
      yagG: _parseDouble(json['toplam_yag'] ?? json['yag_g']) ?? 0.0,
      ogunler: parsedOgunler,
    );
  }

  /// Mevcut nesnenin bir kopyasını, yalnızca verilen alanları değiştirerek
  /// üretir. Modeller değişmez (immutable) olduğu için güncelleme bu yolla yapılır.
  GunlukBeslenmeModel copyWith({
    String? tarih,
    int? suMl,
    int? kaloriKcal,
    double? proteinG,
    double? karbonhidratG,
    double? yagG,
    Map<String, List<OgunKaydiModel>>? ogunler,
  }) {
    return GunlukBeslenmeModel(
      tarih: tarih ?? this.tarih,
      suMl: suMl ?? this.suMl,
      kaloriKcal: kaloriKcal ?? this.kaloriKcal,
      proteinG: proteinG ?? this.proteinG,
      karbonhidratG: karbonhidratG ?? this.karbonhidratG,
      yagG: yagG ?? this.yagG,
      ogunler: ogunler ?? this.ogunler,
    );
  }

  // --- İlerleme oranları ---------------------------------------------------
  // Her oran 0.0–1.0 aralığında sınırlanır; ilerleme çubukları doğrudan
  // bu değerleri kullanır (hedef aşılsa bile çubuk %100'de kalır).

  /// Su hedefine ulaşma oranı (0.0–1.0).
  double get suYuzdesi => (suMl / gunlukSuHedefMl).clamp(0.0, 1.0);

  /// Kalori hedefine ulaşma oranı (0.0–1.0).
  double get kaloriYuzdesi => (kaloriKcal / gunlukKaloriHedef).clamp(0.0, 1.0);

  /// Protein hedefine ulaşma oranı (0.0–1.0).
  double get proteinYuzdesi => (proteinG / gunlukProteinHedefG).clamp(0.0, 1.0);

  /// Karbonhidrat hedefine ulaşma oranı (0.0–1.0).
  double get karbonhidratYuzdesi =>
      (karbonhidratG / gunlukKarbonhidratHedefG).clamp(0.0, 1.0);

  /// Yağ hedefine ulaşma oranı (0.0–1.0).
  double get yagYuzdesi => (yagG / gunlukYagHedefG).clamp(0.0, 1.0);
}

/// Gelen değeri güvenli biçimde tam sayıya çevirir; çevrilemezse `null` döner.
int? _parseInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

/// Gelen değeri güvenli biçimde ondalık sayıya çevirir.
/// Türkçe ondalık ayracı (virgül) da noktaya çevrilerek desteklenir.
double? _parseDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  final normalized = value.toString().trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}
