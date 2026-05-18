class GunlukBeslenmeModel {
  final String tarih;
  final int suMl;
  final int kaloriKcal;
  final double proteinG;
  final double karbonhidratG;
  final double yagG;

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
  });

  factory GunlukBeslenmeModel.fromJson(Map<String, dynamic> json) {
    return GunlukBeslenmeModel(
      tarih: (json['tarih'] ?? '').toString(),
      suMl: _parseInt(json['su_ml']) ?? 0,
      kaloriKcal: _parseInt(json['kalori_kcal']) ?? 0,
      proteinG: _parseDouble(json['protein_g']) ?? 0.0,
      karbonhidratG: _parseDouble(json['karbonhidrat_g']) ?? 0.0,
      yagG: _parseDouble(json['yag_g']) ?? 0.0,
    );
  }

  GunlukBeslenmeModel copyWith({
    String? tarih,
    int? suMl,
    int? kaloriKcal,
    double? proteinG,
    double? karbonhidratG,
    double? yagG,
  }) {
    return GunlukBeslenmeModel(
      tarih: tarih ?? this.tarih,
      suMl: suMl ?? this.suMl,
      kaloriKcal: kaloriKcal ?? this.kaloriKcal,
      proteinG: proteinG ?? this.proteinG,
      karbonhidratG: karbonhidratG ?? this.karbonhidratG,
      yagG: yagG ?? this.yagG,
    );
  }

  double get suYuzdesi =>
      (suMl / gunlukSuHedefMl).clamp(0.0, 1.0);

  double get kaloriYuzdesi =>
      (kaloriKcal / gunlukKaloriHedef).clamp(0.0, 1.0);

  double get proteinYuzdesi =>
      (proteinG / gunlukProteinHedefG).clamp(0.0, 1.0);

  double get karbonhidratYuzdesi =>
      (karbonhidratG / gunlukKarbonhidratHedefG).clamp(0.0, 1.0);

  double get yagYuzdesi =>
      (yagG / gunlukYagHedefG).clamp(0.0, 1.0);

  static int? _parseInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double? _parseDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final normalized = value.toString().trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }
}
