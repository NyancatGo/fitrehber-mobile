class BesinModel {
  final int id;
  final String isim;
  final String? marka;
  final String? barkod;
  final int kalori100g;
  final double protein100g;
  final double karbonhidrat100g;
  final double yag100g;
  final bool isVerified;

  const BesinModel({
    required this.id,
    required this.isim,
    this.marka,
    this.barkod,
    required this.kalori100g,
    required this.protein100g,
    required this.karbonhidrat100g,
    required this.yag100g,
    required this.isVerified,
  });

  factory BesinModel.fromJson(Map<String, dynamic> json) {
    return BesinModel(
      id: _parseInt(json['id']) ?? 0,
      isim: (json['isim'] ?? '').toString(),
      marka: json['marka']?.toString(),
      barkod: json['barkod']?.toString(),
      kalori100g: _parseInt(json['kalori_100g']) ?? 0,
      protein100g: _parseDouble(json['protein_100g']) ?? 0.0,
      karbonhidrat100g: _parseDouble(json['karbonhidrat_100g']) ?? 0.0,
      yag100g: _parseDouble(json['yag_100g']) ?? 0.0,
      isVerified: json['is_verified'] as bool? ?? false,
    );
  }
}

class OgunKaydiModel {
  final int id;
  final String tarih;
  final String ogunTipi;
  final int? besinId;
  final String besinIsim;
  final double miktar;
  final String miktarBirimi;
  final int kalori;
  final double protein;
  final double karbonhidrat;
  final double yag;

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
  });

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
    );
  }
}

class GunlukBeslenmeModel {
  final String tarih;
  final int suMl;
  final int kaloriKcal;
  final double proteinG;
  final double karbonhidratG;
  final double yagG;
  final Map<String, List<OgunKaydiModel>> ogunler;

  static const int gunlukSuHedefMl = 2500;
  static const int gunlukKaloriHedef = 2000;
  static const double gunlukProteinHedefG = 150;
  static const double gunlukKarbonhidratHedefG = 250;
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

  factory GunlukBeslenmeModel.fromJson(Map<String, dynamic> json) {
    final ogunlerJson = json['ogunler'] as Map<String, dynamic>? ?? {};
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

  double get suYuzdesi => (suMl / gunlukSuHedefMl).clamp(0.0, 1.0);

  double get kaloriYuzdesi => (kaloriKcal / gunlukKaloriHedef).clamp(0.0, 1.0);

  double get proteinYuzdesi => (proteinG / gunlukProteinHedefG).clamp(0.0, 1.0);

  double get karbonhidratYuzdesi =>
      (karbonhidratG / gunlukKarbonhidratHedefG).clamp(0.0, 1.0);

  double get yagYuzdesi => (yagG / gunlukYagHedefG).clamp(0.0, 1.0);
}

int? _parseInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double? _parseDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  final normalized = value.toString().trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}
