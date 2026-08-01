import 'dart:convert';

import 'package:fitrehber_mobile/shared/models/beslenme_model.dart';
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

  test(
    'YerelBesin.fromBesinModel barkod sonucunu porsiyon akisina cevirir',
    () {
      final food = YerelBesin.fromBesinModel(
        BesinModel.fromJson({
          'id': 77,
          'isim': 'Barkodlu Sut',
          'marka': 'Fit Marka',
          'barkod': '8690000000092',
          'kalori_100g': 100,
          'protein_100g': 10,
          'karbonhidrat_100g': 10,
          'yag_100g': 4,
          'is_verified': false,
          'quality_score': 95,
          'quality_status': 'good',
          'source_type': 'openfoodfacts',
          'aliases': ['protein sut'],
          'porsiyonlar': [
            {
              'id': 9,
              'isim': 'Sise',
              'gram_esdegeri': 250,
              'varsayilan': true,
              'sira': 1,
            },
          ],
        }),
      );

      expect(food.id, '8690000000092');
      expect(food.besinId, 77);
      expect(food.isim, 'Barkodlu Sut');
      expect(food.kalori100g, 100);
      expect(food.sourceType, 'openfoodfacts');
      expect(food.varsayilanPorsiyon?.isim, 'Sise');
    },
  );

  test('hazirla senkron onbelleginden yukler', () async {
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
        _serverFood(id: 2, kaynakId: 'good-food', isim: 'Gecerli Besin'),
      ]),
    });
    YerelBesinVeritabani.instance.resetForTests();

    await YerelBesinVeritabani.instance.hazirla();

    expect(YerelBesinVeritabani.instance.toplamSayi, 1);
    expect(YerelBesinVeritabani.instance.ara('Reddedilen'), isEmpty);
    expect(YerelBesinVeritabani.instance.ara('Gecerli'), hasLength(1));
  });

  test('cache yoksa veritabani bos kalir — bundled seed fallback YOK', () async {
    await YerelBesinVeritabani.instance.hazirla();

    // Bundled JSON seed kaldirildi: onbellek bosken arama yapilamaz, ekran
    // ilk senkronu bekler. Eskiden burada asset'ten ~3900 kayit yuklenirdi ve
    // bu kayitlar besin_id tasimadigi icin custom-food ogun kaydi uretirdi.
    expect(YerelBesinVeritabani.instance.toplamSayi, 0);
    expect(YerelBesinVeritabani.instance.hazirMi, isFalse);
    expect(YerelBesinVeritabani.instance.ara('elma'), isEmpty);
    expect(YerelBesinVeritabani.instance.tumunuGetir(), isEmpty);
  });

  test('sunucu PKsi olmayan cache kaydi elenir', () async {
    final pksiz = _serverFood(id: 0, kaynakId: 'pksiz', isim: 'PKsiz Besin');
    pksiz.remove('id');
    SharedPreferences.setMockInitialValues({
      YerelBesinVeritabani.cacheKey: jsonEncode([
        pksiz,
        _serverFood(id: 5, kaynakId: 'gecerli', isim: 'Gecerli Besin'),
      ]),
    });
    YerelBesinVeritabani.instance.resetForTests();

    await YerelBesinVeritabani.instance.hazirla();

    // besin_id olmayan kayit ogun eklerken custom-food yoluna duserdi.
    expect(YerelBesinVeritabani.instance.toplamSayi, 1);
    expect(YerelBesinVeritabani.instance.ara('PKsiz'), isEmpty);
    expect(YerelBesinVeritabani.instance.ara('Gecerli').single.besinId, 5);
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
