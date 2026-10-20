// ---------------------------------------------------------------------------
// KİMLİK DOĞRULAMA SERVİSİ
// ---------------------------------------------------------------------------
// Giriş, kayıt, Google OAuth, e-posta doğrulama ve parola sıfırlama akışlarını
// tek yerde toplar. JWT token'ları `flutter_secure_storage` içinde saklanır.
// Kayıt ve e-posta işlemleri WEB projesinin sahipliğindeki JSON uç noktalarına
// gider; bu yüzden URL path'leri backend kontratı olarak İngilizce kalır.
// ---------------------------------------------------------------------------

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/constants/api_sabitleri.dart';
import 'models/kullanici_model.dart';

/// Giriş, kayıt ve oturum yönetimi işlemlerini yürüten servis.
class KimlikServisi {
  final Dio _dio = Dio(
    BaseOptions(
      validateStatus: (status) => true,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Kullanıcı adı ve parola ile giriş yapar.
  ///
  /// Başarılı olursa dönen token'lar güvenli depoya kaydedilir ve kullanıcı
  /// bilgisi döndürülür; aksi halde anlaşılır bir hata mesajı fırlatılır.
  Future<KullaniciModel> girisYap(String username, String password) async {
    final response = await _dio.post(
      ApiSabitleri.girisYap,
      data: {'username': username, 'password': password},
    );

    if (response.statusCode == 200) {
      return _oturumYanitiKaydet(response.data);
    }

    throw _hataAyikla(response.data, response.statusCode);
  }

  /// Yeni kullanıcı kaydı oluşturur.
  ///
  /// Kayıt başarılıysa token beklenmez; WEB tarafı kullanıcıyı inactive açar
  /// ve doğrulama e-postasını gönderir. Giriş, e-posta doğrulandıktan sonradır.
  Future<void> kayitOl(
    String username,
    String password,
    String email,
    String password2,
  ) async {
    final response = await _dio.post(
      ApiSabitleri.kayitOl,
      data: {
        'username': username,
        'email': email,
        'password': password,
        'password2': password2,
      },
    );

    if (response.statusCode == 201) return;

    throw _hataAyikla(response.data, response.statusCode);
  }

  /// Doğrulama e-postasını verilen adrese yeniden gönderir.
  Future<void> dogrulamaMailiTekrarGonder(String email) async {
    final response = await _dio.post(
      ApiSabitleri.dogrulamaMailiTekrarGonder,
      data: {'email': email},
    );

    if (response.statusCode == 200) {
      return;
    }

    throw _hataAyikla(response.data, response.statusCode);
  }

  /// Verilen e-posta adresine parola sıfırlama bağlantısı gönderilmesini ister.
  Future<void> sifreSifirlamaIste(String email) async {
    final response = await _dio.post(
      ApiSabitleri.sifreSifirlamaIste,
      data: {'email': email},
    );

    if (response.statusCode == 200) {
      return;
    }

    throw _hataAyikla(response.data, response.statusCode);
  }

  /// Google'dan alınan yetkilendirme kodunu uygulama oturumuna dönüştürür.
  ///
  /// [code] Google'ın verdiği tek kullanımlık koddur; [state] ve [codeVerifier]
  /// PKCE/CSRF güvenlik kontrolü için kullanılır.
  Future<KullaniciModel> googleKoduIleOturumAc({
    required String code,
    required String state,
    required String codeVerifier,
  }) async {
    final response = await _dio.post(
      ApiSabitleri.googleToken,
      data: {'code': code, 'state': state, 'code_verifier': codeVerifier},
    );

    if (response.statusCode == 200) {
      return _oturumYanitiKaydet(response.data);
    }

    throw _hataAyikla(response.data, response.statusCode);
  }

  Future<KullaniciModel> _oturumYanitiKaydet(dynamic data) async {
    if (data is! Map<String, dynamic>) {
      throw 'Sunucu oturum bilgilerini beklenen formatta döndürmedi.';
    }

    final kullaniciJson = data['kullanici'];
    final kullanici = KullaniciModel.fromJson(
      kullaniciJson,
      data['access'],
      data['refresh'],
    );
    await _tokenKaydet(
      kullanici.accessToken,
      kullanici.refreshToken,
      expiresIn: data['expires_in'],
    );
    await _kullaniciKaydet(kullaniciJson);
    return kullanici;
  }

  /// Access token'in bitiş zamanı (epoch ms). Proaktif yenileme için.
  static const _accessExpiryKey = 'access_token_expires_at';

  /// Access token bitiş zamanının BELLEKTEKI kopyasi (tüm örneklerde paylaşılan).
  ///
  /// Neden bellekte de tutuyoruz? Proaktif yenileme kontrolü HER istek
  /// öncesinde çalışır; güvenli depoya (secure storage) her istekte erişmek
  /// hem gereksiz I/O'dur hem de platform eklentisine bağımlılık yaratır
  /// (masaüstü eklentileri test ortamında takılabiliyor).
  ///
  /// Neden statik? KimlikServisi birden fazla yerde örnekleniyor (ApiServisi
  /// ve Riverpod provider ayrı örnekler oluşturuyor). Süre tek oturuma
  /// ait olduğu için statik tutulur; böylece hangi örnekten girilirse
  /// girelsin aynı bilgi görülür.
  static int? _accessBitisMs;

  Future<void> _tokenKaydet(
    String access,
    String refresh, {
    Object? expiresIn,
  }) async {
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
    await _sureYaz(expiresIn);
  }

  /// `expires_in` (saniye) bilgisi yoksa süreyi temizler — böylece istemci
  /// "süre bilinmiyor" durumunda her istekte yenileme yapmaz, eski davranışı
  /// (401'e düşünce yenileme) sürdürür.
  Future<void> _sureYaz(Object? expiresIn) async {
    // JSON'dan int veya double gelebilir; ikisini de tolere ediyoruz.
    final saniye = expiresIn is num
        ? expiresIn.toInt()
        : int.tryParse(expiresIn?.toString() ?? '');
    if (saniye == null || saniye <= 0) {
      _accessBitisMs = null;
      await _storage.delete(key: _accessExpiryKey);
      return;
    }
    final bitis = DateTime.now()
        .add(Duration(seconds: saniye))
        .millisecondsSinceEpoch;
    _accessBitisMs = bitis;
    await _storage.write(key: _accessExpiryKey, value: '$bitis');
  }

  /// Uygulama acilisinda saklanan token suresini bellege yukler.
  ///
  /// Oturum yuklemesi sirasinda (token okunurken) cagrilir; boylece istek
  /// yolunda guvenli depoya erisim olmaz.
  Future<void> sureYukle() async {
    try {
      final ham = await _storage.read(key: _accessExpiryKey);
      _accessBitisMs = (ham == null || ham.isEmpty)
          ? null
          : int.tryParse(ham);
    } catch (_) {
      _accessBitisMs = null;
    }
  }

  Future<void> _kullaniciKaydet(dynamic kullanici) async {
    if (kullanici is Map<String, dynamic>) {
      await _storage.write(key: 'current_user', value: jsonEncode(kullanici));
    } else if (kullanici is Map) {
      await _storage.write(
        key: 'current_user',
        value: jsonEncode(Map<String, dynamic>.from(kullanici)),
      );
    }
  }

  /// Güvenli depodaki erişim token'ını okur; yoksa `null` döner.
  Future<String?> accessTokenOku() async {
    return await _storage.read(key: 'access_token');
  }

  /// Kayıtlı bir erişim token'ı olup olmadığına bakarak oturum durumunu döner.
  Future<bool> oturumVarMi() async {
    final token = await _storage.read(key: 'access_token');
    return token != null;
  }

  /// Oturumu kapatır: tüm token'ları ve kullanıcı verisini güvenli depodan siler.
  Future<void> cikisYap() async {
    await _storage.deleteAll();
  }

  // Access token kısa, refresh token daha uzun ömürlüdür. Aynı anda birden çok
  // istek 401 alırsa tek refresh çağrısı yapılır; hepsi aynı Future'ı bekler.
  Future<bool>? _refreshInFlight;

  /// Erişim token'ını yeniler. Aynı anda birden fazla çağrı gelse bile
  /// tek bir yenileme isteği yapılır (single-flight); hepsi aynı sonucu bekler.
  Future<bool> accessTokenYenile() {
    return _refreshInFlight ??= _performTokenRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  /// Access token'in omru dolmak uzereyse (veya suresi bilinmiyorsa) yeniler.
  ///
  /// Proaktif yenileme: once her uygulama acilisinda ilk istek 401 aliyor,
  /// sonra yenileme yapiliyor ve istek tekrarlaniyordu. Simdi token suresi
  /// biliniyorsa istek ATILMADAN once yenileme yapilir.
  ///
  /// Guvenli davranis: sure bilinmiyorsa hicbir sey yapilmaz (eski
  /// davranis — 401'e dusulunce yenilenir). Yalnizca BELLEKTEKI surEYi
  /// kullanir; istek yolunda guvenli depoya erisim yapilmaz.
  Future<bool> accessTokenGerekiyorsaYenile({
    Duration pay = const Duration(seconds: 60),
  }) async {
    final bitis = _accessBitisMs;
    if (bitis == null) return false;

    final kalanMs = bitis - DateTime.now().millisecondsSinceEpoch;
    if (kalanMs > pay.inMilliseconds) return false;

    return accessTokenYenile();
  }

  Future<bool> _performTokenRefresh() async {
    final refresh = await _storage.read(key: 'refresh_token');
    if (refresh == null || refresh.isEmpty) return false;

    try {
      final response = await _dio.post(
        ApiSabitleri.tokenRefresh,
        data: {'refresh': refresh},
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map;
        final access = data['access']?.toString();
        if (access == null || access.isEmpty) return false;

        await _storage.write(key: 'access_token', value: access);
        // ROTATE_REFRESH_TOKENS=True ise sunucu yeni refresh token döndürebilir.
        // Dönerse kalıcı depoyu da güncel tutuyoruz.
        final newRefresh = data['refresh']?.toString();
        if (newRefresh != null && newRefresh.isNotEmpty) {
          await _storage.write(key: 'refresh_token', value: newRefresh);
        }
        // Yeni access token'in suresi de guncellenmeli; aksi halde bir sonraki
        // istekte "sure doldu" sanip tekrar yenilemeye kalkardi.
        await _sureYaz(data['expires_in']);
        return true;
      }
      return false;
    } catch (_) {
      // Ağ hatası refresh'i başarısız sayar; oturumu kapatma kararını üst katman verir.
      return false;
    }
  }

  // Web Google OAuth tüm sayfayı yeniler. CSRF/PKCE değerleri kaybolmasın diye
  // `state` ve `codeVerifier` dönüşe kadar güvenli depoda tutulur.
  static const _googlePendingStateKey = 'google_oauth_pending_state';
  static const _googlePendingVerifierKey = 'google_oauth_pending_verifier';

  Future<void> bekleyenGoogleIstekKaydet({
    required String state,
    required String codeVerifier,
  }) async {
    await _storage.write(key: _googlePendingStateKey, value: state);
    await _storage.write(key: _googlePendingVerifierKey, value: codeVerifier);
  }

  Future<({String state, String codeVerifier})?>
  bekleyenGoogleIstekOku() async {
    final state = await _storage.read(key: _googlePendingStateKey);
    final verifier = await _storage.read(key: _googlePendingVerifierKey);
    if (state == null ||
        state.isEmpty ||
        verifier == null ||
        verifier.isEmpty) {
      return null;
    }
    return (state: state, codeVerifier: verifier);
  }

  Future<void> bekleyenGoogleIstekTemizle() async {
    await _storage.delete(key: _googlePendingStateKey);
    await _storage.delete(key: _googlePendingVerifierKey);
  }

  String _hataAyikla(dynamic data, int? statusCode) {
    if (data is String) {
      if (statusCode == 401) return 'Kullanıcı adı veya şifre hatalı.';
      if (statusCode == 403) return 'Bu işlem için izniniz yok.';
      if (statusCode == 400) return 'Geçersiz istek. Bilgilerini kontrol et.';
      return 'Sunucu hatası ($statusCode). Lütfen tekrar dene.';
    }

    if (data is Map) {
      if (data['code'] == 'email_verification_required') {
        throw EpostaDogrulamasiGerekliHatasi(data['email']?.toString() ?? '');
      }

      final directMessage =
          data['hata'] ?? data['detail'] ?? data['message'] ?? data['mesaj'];
      if (directMessage != null) return directMessage.toString();

      final errorMessage = _errorsToMessage(data['errors']);
      if (errorMessage != null) return errorMessage;
    }

    return 'Bilinmeyen hata oluştu.';
  }

  String? _errorsToMessage(dynamic errors) {
    if (errors is List && errors.isNotEmpty) {
      return errors.first.toString();
    }

    if (errors is Map) {
      for (final value in errors.values) {
        final message = _errorsToMessage(value);
        if (message != null && message.isNotEmpty) return message;
      }
    }

    return null;
  }
}

/// Giriş yapılmak istenen hesabın e-postası henüz doğrulanmadığında fırlatılır.
///
/// Ekran katmanı bu özel hatayı yakalayıp kullanıcıyı doğrulama ekranına
/// yönlendirir (sıradan bir hata mesajı göstermek yerine).
class EpostaDogrulamasiGerekliHatasi implements Exception {
  /// Doğrulanması gereken e-posta adresi.
  final String email;

  EpostaDogrulamasiGerekliHatasi(this.email);

  @override
  String toString() => 'E-posta doğrulaması gerekiyor.';
}
