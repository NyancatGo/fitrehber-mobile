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
    expect(food.qualityScore, 95);
    expect(food.qualityStatus, 'verified');
    expect(food.sourceType, 'openfoodfacts');
    expect(food.aliases, contains('Proteinli sut alias'));
  });

  test('YerelBesin.fromCache porsiyonlari siralar ve varsayilani secer', () {
    final food = YerelBesin.fromCache(
      _serverFood(
        id: 42,
        kaynakId: 'portion-food',
        isim: 'Yulaf Ezmesi',
        porsiyonlar: [
          {
            'id': 2,
            'isim': 'Yemek Kasigi',
            'gram_esdegeri': 10,
            'varsayilan': false,
            'sira': 20,
          },
          {
            'id': 1,
            'isim': 'Porsiyon',
            'gram_esdegeri': 40,
            'varsayilan': true,
            'sira': 10,
          },
        ],
      ),
    );

    expect(food.porsiyonlar.map((p) => p.isim), ['Porsiyon', 'Yemek Kasigi']);
    expect(food.varsayilanPorsiyon?.isim, 'Porsiyon');
    expect(food.varsayilanPorsiyon?.gramEsdegeri, 40);
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

  test('offline arama alias kullanir ve kaliteli sonucu one alir', () async {
    SharedPreferences.setMockInitialValues({
      YerelBesinVeritabani.cacheKey: jsonEncode([
        _serverFood(
          id: 1,
          kaynakId: 'low-quality',
          isim: 'Aliasli Besin',
          aliases: ['sporcu sut'],
          qualityScore: 50,
          verified: false,
        ),
        _serverFood(
          id: 2,
          kaynakId: 'high-quality',
          isim: 'Kaliteli Besin',
          aliases: ['sporcu sut'],
          qualityScore: 98,
          verified: true,
        ),
      ]),
    });
    YerelBesinVeritabani.instance.resetForTests();

    await YerelBesinVeritabani.instance.hazirla();

    final results = YerelBesinVeritabani.instance.ara('sporcu sut');
    expect(results.map((f) => f.besinId), [2, 1]);
  });

  test('rejected cache kayitlarini yuklemez', () async {
    SharedPreferences.setMockInitialValues({
      YerelBesinVeritabani.cacheKey: jsonEncode([
        _serverFood(
          id: 1,
          kaynakId: 'rejected-food',
          isim: 'Reddedilen Besin',
          qualityStatus: 'rejected',
        ),
        _serverFood(
          id: 2,
          kaynakId: 'good-food',
          isim: 'Gecerli Besin',
        ),
      ]),
    });
    YerelBesinVeritabani.instance.resetForTests();

    await YerelBesinVeritabani.instance.hazirla();

    expect(YerelBesinVeritabani.instance.toplamSayi, 1);
    expect(YerelBesinVeritabani.instance.ara('Reddedilen'), isEmpty);
    expect(YerelBesinVeritabani.instance.ara('Gecerli'), hasLength(1));
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
  List<Map<String, dynamic>> porsiyonlar = const [],
  List<String> aliases = const ['Proteinli sut alias'],
  int qualityScore = 95,
  String? qualityStatus,
  bool verified = true,
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
    'is_verified': verified,
    'quality_score': qualityScore,
    'quality_status': qualityStatus ?? (verified ? 'verified' : 'needs_review'),
    'source_type': 'openfoodfacts',
    'aliases': aliases,
    'updated_at': '2026-06-17T10:00:00Z',
    'porsiyonlar': porsiyonlar,
  };
}
