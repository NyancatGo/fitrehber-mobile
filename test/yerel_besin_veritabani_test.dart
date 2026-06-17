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

  test('YerelBesin.fromCache sunucu payloadunu besinId ile mapler', () {
    final food = YerelBesin.fromCache(
      _serverFood(
        id: 42,
        kaynakId: '8690000000001',
        isim: 'Proteinli Sut',
        marka: 'Fit Marka',
      ),
    );

    expect(food.id, '8690000000001');
    expect(food.besinId, 42);
    expect(food.isim, 'Proteinli Sut');
    expect(food.marka, 'Fit Marka');
    expect(food.kalori100g, 72);
    expect(food.protein100g, 7.5);
    expect(food.dogrulanmisMi, isTrue);
  });

  test('hazirla cache varsa bundled asset yerine cache kullanir', () async {
    SharedPreferences.setMockInitialValues({
      YerelBesinVeritabani.cacheKey: jsonEncode([
        _serverFood(id: 7, kaynakId: 'cache-food', isim: 'Cache Ozel Besin'),
      ]),
    });
    YerelBesinVeritabani.instance.resetForTests();

    await YerelBesinVeritabani.instance.hazirla();

    expect(YerelBesinVeritabani.instance.toplamSayi, 1);
    final results = YerelBesinVeritabani.instance.ara('cache');
    expect(results, hasLength(1));
    expect(results.single.besinId, 7);
    expect(results.single.id, 'cache-food');
  });

  test('cache yoksa bundled JSON fallback yuklenir', () async {
    await YerelBesinVeritabani.instance.hazirla();

    expect(YerelBesinVeritabani.instance.toplamSayi, greaterThan(0));
  });
}

Map<String, dynamic> _serverFood({
  required int id,
  required String kaynakId,
  required String isim,
  String marka = '',
}) {
  return {
    'id': id,
    'kaynak_id': kaynakId,
    'isim': isim,
    'isim_ingilizce': 'Protein Milk',
    'marka': marka,
    'barkod': kaynakId,
    'kalori_100g': 72,
    'protein_100g': 7.5,
    'karbonhidrat_100g': 4.8,
    'yag_100g': 1.5,
    'sodyum_100g': 45,
    'potasyum_100g': 0,
    'kolesterol_100g': 0,
    'lif_100g': 0,
    'seker_100g': 4.8,
    'doymus_yag_100g': 0.8,
    'is_verified': true,
    'updated_at': '2026-06-17T10:00:00Z',
  };
}
