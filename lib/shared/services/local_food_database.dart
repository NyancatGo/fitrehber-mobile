import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Yerel JSON veritabanından besin araması yapan servis.
/// Uygulama başlatıldığında dosya bir kez okunup bellekte tutulur.
/// Tüm aramalar offline (milisaniye düzeyinde) gerçekleşir.
class LocalFoodDatabase {
  LocalFoodDatabase._();
  static final instance = LocalFoodDatabase._();

  List<LocalFoodItem>? _foods;
  bool _isLoading = false;

  /// Veritabanını bellekte hazırlar. İlk çağrıda JSON parse eder,
  /// sonraki çağrılarda önbellekten döner.
  Future<void> initialize() async {
    if (_foods != null || _isLoading) return;
    _isLoading = true;
    try {
      final jsonString =
          await rootBundle.loadString('assets/data/foods_cleaned.json');
      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      _foods = jsonList
          .map(
            (item) =>
                LocalFoodItem.fromJson(item as Map<String, dynamic>),
          )
          .where((f) => f.kalori100g > 0) // Boş verileri filtrele
          .toList();
    } catch (e) {
      _foods = [];
    } finally {
      _isLoading = false;
    }
  }

  /// Tüm yüklü besinlerin sayısını döner.
  int get totalCount => _foods?.length ?? 0;

  /// Besin arar. Türkçe isim ve İngilizce isimde aynı anda arar.
  /// Sonuçlar alakalılık sırasına göre sıralanır (tam eşleşme > başlangıç > içerik).
  List<LocalFoodItem> search(String query, {int limit = 50}) {
    final foods = _foods;
    if (foods == null || query.trim().isEmpty) return [];

    final q = _turkishLower(query.trim());
    final words = q.split(RegExp(r'\s+'));

    final results = <_ScoredItem>[];

    for (final food in foods) {
      final name = _turkishLower(food.isim);
      final nameEn = food.isimIngilizce.toLowerCase();

      int score = 0;

      // Tam eşleşme (en yüksek puan)
      if (name == q) {
        score = 100;
      }
      // Başlangıçla eşleşme
      else if (name.startsWith(q)) {
        score = 80;
      }
      // İçerik eşleşmesi
      else if (name.contains(q)) {
        score = 60;
      }
      // Kelime bazında arama (her kelime besinin isminde geçiyorsa)
      else if (words.every((w) => name.contains(w) || nameEn.contains(w))) {
        score = 40;
      }
      // İngilizce isimde arama
      else if (nameEn.contains(q)) {
        score = 20;
      }

      if (score > 0) {
        results.add(_ScoredItem(food, score));
      }
    }

    // Skora göre azalan, sonra isme göre alfabetik sırala
    results.sort((a, b) {
      final cmp = b.score.compareTo(a.score);
      if (cmp != 0) return cmp;
      return a.item.isim.compareTo(b.item.isim);
    });

    return results.take(limit).map((s) => s.item).toList();
  }

  /// Popüler / önerilen besinleri getirir (kalori > 0 olan ilk N tane).
  List<LocalFoodItem> getPopular({int limit = 20}) {
    final foods = _foods;
    if (foods == null) return [];
    // Yüksek kalorili olanları sırala (kullanıcının en çok arayacağı besinler)
    final sorted = List<LocalFoodItem>.from(foods)
      ..sort((a, b) => b.kalori100g.compareTo(a.kalori100g));
    return sorted.take(limit).toList();
  }

  /// Türkçe küçük harf dönüşümü (İ->i, I->ı gibi).
  static String _turkishLower(String s) {
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

class _ScoredItem {
  final LocalFoodItem item;
  final int score;
  _ScoredItem(this.item, this.score);
}

/// Yerel JSON'dan okunan tek bir besin maddesi.
class LocalFoodItem {
  final String id;
  final String isim;
  final String isimIngilizce;

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

  final bool isVerified;

  const LocalFoodItem({
    required this.id,
    required this.isim,
    required this.isimIngilizce,
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
    required this.isVerified,
  });

  factory LocalFoodItem.fromJson(Map<String, dynamic> json) {
    return LocalFoodItem(
      id: (json['id'] ?? '').toString(),
      isim: (json['isim'] ?? '').toString().trim(),
      isimIngilizce: (json['isim_ingilizce'] ?? '').toString().trim(),
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
      isVerified: json['isVerified'] as bool? ?? false,
    );
  }

  /// Gramaja göre hesaplanmış kaloriyi döner.
  double kaloriForGram(double gram) => (kalori100g * gram) / 100;
  double proteinForGram(double gram) => (protein100g * gram) / 100;
  double karbonhidratForGram(double gram) => (karbonhidrat100g * gram) / 100;
  double yagForGram(double gram) => (yag100g * gram) / 100;
  double sodyumForGram(double gram) => (sodyum100g * gram) / 100;
  double potasyumForGram(double gram) => (potasyum100g * gram) / 100;
  double kolesterolForGram(double gram) => (kolesterol100g * gram) / 100;
  double lifForGram(double gram) => (lif100g * gram) / 100;
  double sekerForGram(double gram) => (seker100g * gram) / 100;
  double doymusYagForGram(double gram) => (doymusYag100g * gram) / 100;

  static double _d(Object? v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0.0;
  }
}
