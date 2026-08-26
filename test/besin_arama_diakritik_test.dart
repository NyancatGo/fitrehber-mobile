// Türkçe karakter içeren besinlerin ASCII sorguyla bulunabilirliği.
//
// Kullanıcılar mobil klavyede "göğsü" yerine "gogsu", "çorbası" yerine
// "corbasi" yazıyor. Prod arama loglarında bu tür sorgular <=2 sonuç dönmüştü.
//
// GEÇMİŞ: Bu dosya bir dönem sorunu alias üretimine havale ediyordu — sunucu
// ASCII alias üretir, mobil onları kullanır diye. Üretim verisiyle ölçüldüğünde
// bu çözümün tutmadığı görüldü: alias'lar `isim` alanı olarak senkronlanıyor
// (bkz. BesinSyncSerializer.get_aliases) ve o alan ASCII değil — 4.017 besinin
// gerçek verisiyle "cikolata" sorgusu 121 yerine 12 sonuç dönüyordu.
//
// ÇÖZÜM: `_turkceKucult` artık ASCII katlaması da yapıyor. Hem sorgu hem indeks
// aynı fonksiyondan geçtiği için iki taraf hep aynı alfabede. Aşağıdaki testler
// o katlamanın yerinde kalmasını garanti eder — kaldırılırsa buradan yakalanır.
import 'dart:convert';

import 'package:fitrehber_mobile/shared/services/yerel_besin_veritabani.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    YerelBesinVeritabani.instance.resetForTests();
  });

  Future<void> cacheKur(List<Map<String, dynamic>> foods) async {
    SharedPreferences.setMockInitialValues({
      YerelBesinVeritabani.cacheKey: jsonEncode(foods),
    });
    YerelBesinVeritabani.instance.resetForTests();
    await YerelBesinVeritabani.instance.hazirla();
  }

  test('ASCII sorgu, Türkçe karakterli besini alias üzerinden bulur', () async {
    await cacheKur([
      _food(
        id: 1,
        isim: 'Haşlanmış Tavuk Göğsü',
        // sync_aliases_for_food sunucuda bu ASCII varyantı üretiyor
        aliases: ['haslanmis tavuk gogsu'],
      ),
    ]);

    expect(
      YerelBesinVeritabani.instance.ara('tavuk gogsu'),
      isNotEmpty,
      reason: 'ASCII sorgu alias üzerinden eşleşmeli',
    );
  });

  test('ASCII sorgu, alias YOKSA da Türkçe karakterli besini bulur', () async {
    await cacheKur([
      _food(id: 2, isim: 'Mercimek Çorbası', aliases: const []),
    ]);

    // Kritik test: alias yoksa bile eşleşmeli. Katlama kaldırılırsa burası
    // kırmızı yanar — ve prod'da "corba" arayan kullanıcı sonuç göremez.
    expect(
      YerelBesinVeritabani.instance.ara('mercimek corbasi'),
      isNotEmpty,
      reason: 'ASCII katlaması alias olmadan da çalışmalı',
    );
  });

  test('Türkçe karakterli sorgu her hâlükârda eşleşir', () async {
    await cacheKur([
      _food(id: 3, isim: 'Mercimek Çorbası', aliases: const []),
    ]);

    expect(YerelBesinVeritabani.instance.ara('mercimek çorbası'), isNotEmpty);
    expect(YerelBesinVeritabani.instance.ara('Mercimek'), isNotEmpty);
  });

  test('altı Türkçe harfin her biri ASCII karşılığıyla bulunur', () async {
    await cacheKur([
      _food(id: 10, isim: 'Fıstık', aliases: const []), // ı -> i
      _food(id: 11, isim: 'Yoğurt', aliases: const []), // ğ -> g
      _food(id: 12, isim: 'Üzüm', aliases: const []), // ü -> u
      _food(id: 13, isim: 'Şeftali', aliases: const []), // ş -> s
      _food(id: 14, isim: 'Söğüş', aliases: const []), // ö -> o
      _food(id: 15, isim: 'Çilek', aliases: const []), // ç -> c
    ]);

    const beklenen = <String, int>{
      'fistik': 10,
      'yogurt': 11,
      'uzum': 12,
      'seftali': 13,
      'sogus': 14,
      'cilek': 15,
    };

    beklenen.forEach((sorgu, besinId) {
      expect(
        YerelBesinVeritabani.instance.ara(sorgu).map((f) => f.besinId),
        contains(besinId),
        reason: '"$sorgu" sorgusu eşleşmeli',
      );
    });
  });

  test('büyük İ ve I görünmez birleşik nokta bırakmaz', () async {
    // Dart'ın toLowerCase()'i 'İ' için 'i' + U+0307 üretir. Eğer büyük harf
    // eşlemesi katlamadan ÖNCE yapılmazsa arama anahtarında görünmeyen bir
    // karakter kalır ve hiçbir sorgu eşleşmez. Aynı hata API tarafında da
    // vardı (bkz. api/views.py::_normalize_food_text NFKD adımı).
    await cacheKur([
      _food(id: 20, isim: 'İçim Süzme Peynir', aliases: const []),
      _food(id: 21, isim: 'IŞIL Ayran', aliases: const []),
    ]);

    expect(
      YerelBesinVeritabani.instance.ara('icim suzme').map((f) => f.besinId),
      contains(20),
      reason: 'İ -> i eşlemesi katlamadan önce yapılmalı',
    );
    expect(
      YerelBesinVeritabani.instance.ara('İçim').map((f) => f.besinId),
      contains(20),
      reason: 'Kullanıcı Türkçe yazsa da bulmalı',
    );
    expect(
      YerelBesinVeritabani.instance.ara('isil').map((f) => f.besinId),
      contains(21),
      reason: 'I -> ı -> i zinciri çalışmalı',
    );
  });

  test('sorgu ve indeks aynı alfabede — iki yön de eşleşir', () async {
    await cacheKur([
      _food(id: 30, isim: 'Kaşarlı Tost', aliases: const []),
      _food(id: 31, isim: 'kasarli tost', aliases: const []),
    ]);

    // Türkçe yazılmış besin ASCII sorguyla, ASCII yazılmış besin Türkçe
    // sorguyla bulunmalı. Katlama tek taraflı olsaydı biri kaçardı.
    final asciiSorgu = YerelBesinVeritabani.instance
        .ara('kasarli tost')
        .map((f) => f.besinId);
    final turkceSorgu = YerelBesinVeritabani.instance
        .ara('kaşarlı tost')
        .map((f) => f.besinId);

    expect(asciiSorgu, containsAll([30, 31]));
    expect(turkceSorgu, containsAll([30, 31]));
  });
}

Map<String, dynamic> _food({
  required int id,
  required String isim,
  required List<String> aliases,
}) {
  return {
    'id': id,
    'kaynak_id': 'test-$id',
    'isim': isim,
    'isim_ingilizce': '',
    'marka': '',
    'barkod': null,
    'kalori_100g': 120,
    'protein_100g': 20.0,
    'karbonhidrat_100g': 2.0,
    'yag_100g': 3.0,
    'sodyum_100g': 60,
    'potasyum_100g': 0,
    'kolesterol_100g': 0,
    'lif_100g': 0,
    'seker_100g': 0,
    'doymus_yag_100g': 1.0,
    'is_verified': true,
    'quality_score': 100,
    'quality_status': 'good',
    'source_type': 'seed',
    'aliases': aliases,
    'updated_at': '2026-06-17T10:00:00Z',
    'porsiyonlar': const [],
  };
}
