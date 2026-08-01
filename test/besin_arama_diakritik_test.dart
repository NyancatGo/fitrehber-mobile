// Türkçe karakter içeren besinlerin ASCII sorguyla bulunabilirliği.
//
// Kullanıcılar mobil klavyede "göğsü" yerine "gogsu", "çorbası" yerine
// "corbasi" yazıyor. Prod arama loglarında bu tür sorgular <=2 sonuç dönmüştü.
// Sunucu tarafı normalize_food_text diakritikleri ASCII'ye katlıyor ve alias
// üretiyor; bu test mobil aramanın o alias'lardan yararlanıp yararlanmadığını
// doğrular.
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

  test('ASCII sorgu, Türkçe karakterli besni alias üzerinden bulur', () async {
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

  test('ASCII sorgu, alias YOKSA Türkçe karakterli besini bulamaz', () async {
    await cacheKur([
      _food(id: 2, isim: 'Mercimek Çorbası', aliases: const []),
    ]);

    // Bu davranış kasıtlı olarak belgeleniyor: alias yoksa mobil arama
    // diakritik katlaması yapmadığı için sonuç dönmez.
    expect(
      YerelBesinVeritabani.instance.ara('mercimek corbasi'),
      isEmpty,
      reason: 'alias olmadan ASCII sorgu eşleşmiyor — alias üretimi kritik',
    );
  });

  test('Türkçe karakterli sorgu her hâlükârda eşleşir', () async {
    await cacheKur([
      _food(id: 3, isim: 'Mercimek Çorbası', aliases: const []),
    ]);

    expect(YerelBesinVeritabani.instance.ara('mercimek çorbası'), isNotEmpty);
    expect(YerelBesinVeritabani.instance.ara('Mercimek'), isNotEmpty);
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
