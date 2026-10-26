import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fitrehber_mobile/shared/api_servisi.dart';
import 'package:fitrehber_mobile/shared/kimlik_servisi.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _BellekSecureStorage extends FlutterSecureStorage {
  final Map<String, String> depo;

  _BellekSecureStorage() : depo = {}, super();

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      depo.remove(key);
    } else {
      depo[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return depo[key];
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    depo.remove(key);
  }

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    depo.clear();
  }
}

typedef _AdapterYaniti =
    Future<ResponseBody> Function(RequestOptions options);

class _SahteHttpClientAdapter implements HttpClientAdapter {
  final _AdapterYaniti onFetch;
  _SahteHttpClientAdapter(this.onFetch);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return onFetch(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonYanit(int statusCode, Map<String, dynamic> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

void main() {
  test(
    'ApiServisi 401 alınca tokenı bir kez yeniler ve isteği yeni tokenla tekrarlar',
    () async {
      final storage = _BellekSecureStorage();
      await storage.write(key: 'access_token', value: 'eski-access');
      await storage.write(key: 'refresh_token', value: 'gecerli-refresh');

      var refreshCagriSayisi = 0;
      final gonderilenAuthBasliklari = <String?>[];

      final kimlikDio = Dio(BaseOptions(validateStatus: (_) => true));
      kimlikDio.httpClientAdapter = _SahteHttpClientAdapter((options) async {
        refreshCagriSayisi++;
        return _jsonYanit(200, {
          'access': 'yeni-access',
          'refresh': 'yeni-refresh',
          'expires_in': 3600,
        });
      });

      final apiDio = Dio(BaseOptions(validateStatus: (_) => true));
      apiDio.httpClientAdapter = _SahteHttpClientAdapter((options) async {
        final auth = options.headers['Authorization']?.toString();
        gonderilenAuthBasliklari.add(auth);
        if (auth == 'Bearer eski-access') {
          return _jsonYanit(401, {'detail': 'Token süresi doldu.'});
        }
        return _jsonYanit(200, {
          'id': 7,
          'username': 'sporcu',
          'email': 'sporcu@fitrehber.com.tr',
          'is_onboarded': true,
        });
      });

      final kimlik = KimlikServisi(dio: kimlikDio, storage: storage);
      final api = ApiServisi(
        dio: apiDio,
        storage: storage,
        kimlikServisi: kimlik,
      );

      final profil = await api.profiliGetir();

      expect(profil.id, 7);
      expect(profil.username, 'sporcu');
      expect(refreshCagriSayisi, 1);
      expect(gonderilenAuthBasliklari, [
        'Bearer eski-access',
        'Bearer yeni-access',
      ]);
      expect(await storage.read(key: 'access_token'), 'yeni-access');
      expect(await storage.read(key: 'refresh_token'), 'yeni-refresh');
    },
  );

  test(
    'ApiServisi yenilenen token da 401 alırsa sonsuz döngüye girmez ve Türkçe hata fırlatır',
    () async {
      final storage = _BellekSecureStorage();
      await storage.write(key: 'access_token', value: 'eski-access');
      await storage.write(key: 'refresh_token', value: 'gecerli-refresh');

      var apiIstekSayisi = 0;
      final kimlikDio = Dio(BaseOptions(validateStatus: (_) => true));
      kimlikDio.httpClientAdapter = _SahteHttpClientAdapter((options) async {
        return _jsonYanit(200, {'access': 'yine-401-access'});
      });

      final apiDio = Dio(BaseOptions(validateStatus: (_) => true));
      apiDio.httpClientAdapter = _SahteHttpClientAdapter((options) async {
        apiIstekSayisi++;
        return _jsonYanit(401, {'detail': 'Yetkisiz'});
      });

      final kimlik = KimlikServisi(dio: kimlikDio, storage: storage);
      final api = ApiServisi(
        dio: apiDio,
        storage: storage,
        kimlikServisi: kimlik,
      );

      await expectLater(
        api.profiliGetir(),
        throwsA(
          isA<ApiHatasi>()
              .having(
                (e) => e.mesaj,
                'mesaj',
                'Oturum süren dolmuş. Lütfen tekrar giriş yap.',
              )
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.geciciMi, 'geciciMi', isTrue),
        ),
      );
      // İlk deneme + 1 kez retry = toplam 2 istek (sonsuz döngü yok).
      expect(apiIstekSayisi, 2);
    },
  );

  test(
    'KimlikServisi eşzamanlı accessTokenYenile çağrılarını tek HTTP isteğinde birleştirir (single-flight)',
    () async {
      final storage = _BellekSecureStorage();
      await storage.write(key: 'refresh_token', value: 'ortak-refresh');

      var postSayisi = 0;
      final kimlikDio = Dio(BaseOptions(validateStatus: (_) => true));
      kimlikDio.httpClientAdapter = _SahteHttpClientAdapter((options) async {
        postSayisi++;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return _jsonYanit(200, {'access': 'tek-access', 'expires_in': 1800});
      });

      final kimlik1 = KimlikServisi(dio: kimlikDio, storage: storage);
      final kimlik2 = KimlikServisi(dio: kimlikDio, storage: storage);

      final sonuclar = await Future.wait([
        kimlik1.accessTokenYenile(),
        kimlik2.accessTokenYenile(),
        kimlik1.accessTokenYenile(),
      ]);

      expect(sonuclar, [isTrue, isTrue, isTrue]);
      expect(postSayisi, 1);
      expect(await storage.read(key: 'access_token'), 'tek-access');

      await kimlik1.cikisYap();
      expect(await kimlik1.accessTokenGerekiyorsaYenile(), isFalse);
    },
  );

  test(
    'ApiServisi DRF alan doğrulama hatalarını Türkçe alan adlarıyla biçimlendirir',
    () async {
      final storage = _BellekSecureStorage();
      await storage.write(key: 'access_token', value: 'token');
      await storage.delete(key: 'access_token_expires_at');

      final kimlikDio = Dio(BaseOptions(validateStatus: (_) => true));
      final apiDio = Dio(BaseOptions(validateStatus: (_) => true));
      apiDio.httpClientAdapter = _SahteHttpClientAdapter((options) async {
        return _jsonYanit(400, {
          'baslik': ['Bu alan boş bırakılamaz.'],
          'kategori': ['Geçerli bir kategori seçin.'],
        });
      });

      final kimlik = KimlikServisi(dio: kimlikDio, storage: storage);
      await kimlik.sureYukle();
      final api = ApiServisi(
        dio: apiDio,
        storage: storage,
        kimlikServisi: kimlik,
      );

      await expectLater(
        api.soruSor(baslik: '', yazi: 'Test', kategoriId: 1),
        throwsA(
          isA<ApiHatasi>()
              .having(
                (e) => e.toString(),
                'mesaj',
                'Soru paylasilamadi. (Başlık: Bu alan boş bırakılamaz. | Kategori: Geçerli bir kategori seçin.)',
              )
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.kaliciMi, 'kaliciMi', isTrue),
        ),
      );
    },
  );
}
