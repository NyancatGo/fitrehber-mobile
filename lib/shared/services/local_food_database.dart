import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;

/// Yerel JSON veritabanından besin araması yapan servis.
/// Uygulama başlatıldığında dosya bir kez okunup bellekte tutulur.
/// Tüm aramalar offline (milisaniye düzeyinde) gerçekleşir.
class LocalFoodDatabase {
  LocalFoodDatabase._();
  static final instance = LocalFoodDatabase._();

  List<LocalFoodItem>? _foods;
  List<LocalFoodItem>? _sortedFoods;
  Future<void>? _initializing;

  /// Veritabanını bellekte hazırlar. İki kaynak yüklenir:
  ///   - foods_cleaned.json   → generic foods (curated)
  ///   - foods_brands_tr.json → Türkiye'deki markalı ürünler (OpenFoodFacts)
  /// İkincisi yoksa veya bozuksa sadece birincisi kullanılır.
  Future<void> initialize() async {
    if (_foods != null) return;
    final existingInit = _initializing;
    if (existingInit != null) return existingInit;

    _initializing = _loadAll();
    return _initializing!;
  }

  Future<void> _loadAll() async {
    try {
      final generic = await _loadFile('assets/data/foods_cleaned.json');
      final branded = await _loadFile('assets/data/foods_brands_tr.json');
      _foods = [...generic, ...branded].where((f) => f.kalori100g > 0).toList();
      _sortedFoods = List<LocalFoodItem>.from(_foods!)
        ..sort((a, b) => a.isim.compareTo(b.isim));
    } catch (e) {
      _foods = [];
      _sortedFoods = [];
    } finally {
      _initializing = null;
    }
  }

  /// Tek bir JSON dosyasını yükler; bulunamazsa veya bozuksa boş liste döner.
  Future<List<LocalFoodItem>> _loadFile(String assetPath) async {
    try {
      final jsonString = await rootBundle.loadString(assetPath);
      return compute(_parseFoodItems, jsonString);
    } catch (_) {
      return const [];
    }
  }

  /// Tüm yüklü besinlerin sayısını döner.
  int get totalCount => _foods?.length ?? 0;

  /// Besin arar. Türkçe isim ve İngilizce isimde aynı anda arar.
  /// Sonuçlar alakalılık sırasına göre sıralanır (tam eşleşme > başlangıç > içerik).
  List<LocalFoodItem> search(String query, {int limit = 120}) {
    final foods = _foods;
    if (foods == null || query.trim().isEmpty) return [];

    final q = _turkishLower(query.trim());
    final words = q.split(RegExp(r'\s+'));

    final results = <_ScoredItem>[];

    for (final food in foods) {
      final name = food.searchName;
      final nameEn = food.searchEnglishName;
      final brand = food.searchBrand;
      final blob = food.searchBlob;

      int score = 0;

      // Tam eşleşme (en yüksek puan)
      if (name == q) {
        score = 100;
      }
      // Başlangıçla eşleşme
      else if (name.startsWith(q)) {
        score = 80;
      }
      // Marka başlangıcı
      else if (brand.startsWith(q)) {
        score = 70;
      }
      // İçerik eşleşmesi
      else if (name.contains(q)) {
        score = 60;
      }
      // Marka içeriği
      else if (brand.contains(q)) {
        score = 50;
      }
      // Kelime bazında arama (her kelime besinin isminde geçiyorsa)
      else if (words.every(blob.contains)) {
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

  /// Arama boşken gösterilecek varsayılan liste.
  /// Tam veri bellekte kalır; ilk ekranda yalnızca sınırlı ve cache'li alfabetik
  /// liste döndürülür. Kullanıcı yazdıkça tüm veri üzerinde arama yapılır.
  List<LocalFoodItem> getAll({int limit = 150}) {
    final foods = _sortedFoods;
    if (foods == null) return [];
    return foods.take(limit).toList();
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

List<LocalFoodItem> _parseFoodItems(String jsonString) {
  final list = json.decode(jsonString) as List<dynamic>;
  return list
      .whereType<Map>()
      .map((item) => LocalFoodItem.fromJson(Map<String, dynamic>.from(item)))
      .toList();
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
  final String brand; // OFF kaynağı için marka adı; generic foods'ta boş.
  final String searchName;
  final String searchEnglishName;
  final String searchBrand;
  final String searchBlob;

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
    this.brand = '',
    required this.searchName,
    required this.searchEnglishName,
    required this.searchBrand,
    required this.searchBlob,
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
    final isim = (json['isim'] ?? '').toString().trim();
    final isimIngilizce = (json['isim_ingilizce'] ?? '').toString().trim();
    final brand = (json['brand'] ?? '').toString().trim();
    final searchName = LocalFoodDatabase._turkishLower(isim);
    final searchEnglishName = LocalFoodDatabase._turkishLower(isimIngilizce);
    final searchBrand = LocalFoodDatabase._turkishLower(brand);

    return LocalFoodItem(
      id: (json['id'] ?? '').toString(),
      isim: isim,
      isimIngilizce: isimIngilizce,
      brand: brand,
      searchName: searchName,
      searchEnglishName: searchEnglishName,
      searchBrand: searchBrand,
      searchBlob: '$searchName $searchEnglishName $searchBrand',
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
