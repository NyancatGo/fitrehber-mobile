import 'dart:convert';

import 'package:fitrehber_mobile/shared/services/besin_senkron_servisi.dart';
import 'package:fitrehber_mobile/shared/services/yerel_besin_veritabani.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    YerelBesinVeritabani.instance.resetForTests();
  });

  test('ilk senkron tum sayfalari indirip cache ve lastSync yazar', () async {
    final calls = <Map<String, Object?>>[];
    final service = BesinSenkronServisi.test(
      sayfaGetir: ({String? since, int offset = 0, int limit = 1000}) async {
        calls.add({'since': since, 'offset': offset, 'limit': limit});
        if (offset == 0) {
          return {
            'foods': [_serverFood(id: 1, isim: 'Yulaf')],
            'serverTime': '2026-06-17T10:00:00Z',
            'hasMore': true,
            'count': 2,
          };
        }
        return {
          'foods': [_serverFood(id: 2, isim: 'Sut')],
          'serverTime': '2026-06-17T10:00:00Z',
          'hasMore': false,
          'count': 2,
        };
      },
    );

    await service.senkronEt(zorla: true);

    final prefs = await SharedPreferences.getInstance();
    final cached =
        jsonDecode(prefs.getString(YerelBesinVeritabani.cacheKey)!)
            as List<dynamic>;
    expect(cached, hasLength(2));
    expect(
      prefs.getString(YerelBesinVeritabani.lastSyncKey),
      '2026-06-17T10:00:00Z',
    );
    expect(prefs.getInt('besin_cache_schema_version'), 3);
    expect(calls.map((c) => c['offset']).toList(), [0, 1]);
    expect(calls.every((c) => c['since'] == null), isTrue);
    expect(YerelBesinVeritabani.instance.toplamSayi, 2);
  });

  test('delta senkron mevcut cache uzerine id bazli merge yapar', () async {
    const lastSync = '2026-06-17T09:00:00Z';
    SharedPreferences.setMockInitialValues({
      YerelBesinVeritabani.cacheKey: jsonEncode([
        _serverFood(id: 1, isim: 'Yulaf'),
        _serverFood(id: 2, isim: 'Sut'),
      ]),
      YerelBesinVeritabani.lastSyncKey: lastSync,
      YerelBesinVeritabani.lastSyncAtKey: DateTime.now()
          .subtract(const Duration(days: 1))
          .toIso8601String(),
      'besin_cache_schema_version': 3,
    });
    YerelBesinVeritabani.instance.resetForTests();

    final calls = <Map<String, Object?>>[];
    final service = BesinSenkronServisi.test(
      sayfaGetir: ({String? since, int offset = 0, int limit = 1000}) async {
        calls.add({'since': since, 'offset': offset, 'limit': limit});
        return {
          'foods': [_serverFood(id: 2, isim: 'Guncel Sut')],
          'serverTime': '2026-06-17T11:00:00Z',
          'hasMore': false,
          'count': 1,
        };
      },
    );

    await service.senkronEt(zorla: true);

    final prefs = await SharedPreferences.getInstance();
    final cached =
        (jsonDecode(prefs.getString(YerelBesinVeritabani.cacheKey)!)
                as List<dynamic>)
            .cast<Map<dynamic, dynamic>>();
    final updated = cached.firstWhere((item) => item['id'] == 2);
    expect(cached, hasLength(2));
    expect(updated['isim'], 'Guncel Sut');
    expect(
      prefs.getString(YerelBesinVeritabani.lastSyncKey),
      '2026-06-17T11:00:00Z',
    );
    expect(calls.single['since'], lastSync);
    expect(calls.single['offset'], 0);
  });

  test(
    'cache semasi eskiyse throttle atlanir ve tam senkron yapilir',
    () async {
      const lastSync = '2026-06-17T09:00:00Z';
      SharedPreferences.setMockInitialValues({
        YerelBesinVeritabani.cacheKey: jsonEncode([
          _serverFood(id: 1, isim: 'Eski Cache Yulaf'),
        ]),
        YerelBesinVeritabani.lastSyncKey: lastSync,
        YerelBesinVeritabani.lastSyncAtKey: DateTime.now().toIso8601String(),
      });
      YerelBesinVeritabani.instance.resetForTests();

      final calls = <Map<String, Object?>>[];
      final service = BesinSenkronServisi.test(
        sayfaGetir: ({String? since, int offset = 0, int limit = 1000}) async {
          calls.add({'since': since, 'offset': offset, 'limit': limit});
          return {
            'foods': [_serverFood(id: 2, isim: 'Yeni Semali Sut')],
            'serverTime': '2026-06-17T12:00:00Z',
            'hasMore': false,
            'count': 1,
          };
        },
      );

      await service.senkronEt();

      final prefs = await SharedPreferences.getInstance();
      final cached =
          (jsonDecode(prefs.getString(YerelBesinVeritabani.cacheKey)!)
                  as List<dynamic>)
              .cast<Map<dynamic, dynamic>>();
      expect(calls, hasLength(1));
      expect(calls.single['since'], isNull);
      expect(cached, hasLength(1));
      expect(cached.single['isim'], 'Yeni Semali Sut');
      expect(prefs.getInt('besin_cache_schema_version'), 3);
    },
  );
}

Map<String, dynamic> _serverFood({required int id, required String isim}) {
  return {
    'id': id,
    'kaynak_id': 'food-$id',
    'isim': isim,
    'isim_ingilizce': 'Food $id',
    'marka': '',
    'barkod': null,
    'kalori_100g': 100 + id,
    'protein_100g': 10.0,
    'karbonhidrat_100g': 20.0,
    'yag_100g': 5.0,
    'sodyum_100g': 0,
    'potasyum_100g': 0,
    'kolesterol_100g': 0,
    'lif_100g': 1.0,
    'seker_100g': 2.0,
    'doymus_yag_100g': 0.5,
    'is_verified': true,
    'updated_at': '2026-06-17T10:00:00Z',
  };
}
