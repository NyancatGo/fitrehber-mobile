// Kimlik doğrulama işlemlerini yönetir: giriş, kayıt, oturum kontrolü, çıkış.
// Dio: HTTP istekleri için kullanılır.
// FlutterSecureStorage: token'ları telefonda şifreli olarak saklar.

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants/api_constants.dart';
import 'models/kullanici_model.dart';

class AuthService {
  // HTTP istemcisi — validateStatus: true ile 400/401 gibi hatalar da exception değil
  // normal response olarak döner, böylece hata mesajını kendimiz okuyabiliriz.
  final Dio _dio = Dio(BaseOptions(
    validateStatus: (status) => true,
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  // Güvenli yerel depolama (telefon şifrelemesi kullanır)
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // ─── Giriş Yap ───────────────────────────────────────────────────────────
  Future<KullaniciModel> login(String username, String password) async {
    final response = await _dio.post(
      ApiConstants.login,
      data: {'username': username, 'password': password},
    );

    if (response.statusCode == 200) {
      final kullanici = KullaniciModel.fromJson(
        response.data['kullanici'],
        response.data['access'],
        response.data['refresh'],
      );
      await _tokenKaydet(kullanici.accessToken, kullanici.refreshToken);
      return kullanici;
    }

    // Giriş başarısız — API'den gelen hata mesajını göster
    throw _hataAyikla(response.data, response.statusCode);
  }

  // ─── Kayıt Ol ────────────────────────────────────────────────────────────
  Future<KullaniciModel> register(
    String username,
    String password,
    String email,
  ) async {
    final response = await _dio.post(
      ApiConstants.register,
      data: {'username': username, 'password': password, 'email': email},
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final kullanici = KullaniciModel.fromJson(
        response.data['kullanici'],
        response.data['access'],
        response.data['refresh'],
      );
      await _tokenKaydet(kullanici.accessToken, kullanici.refreshToken);
      return kullanici;
    }

    // Kayıt başarısız — API'den gelen hata mesajını göster
    throw _hataAyikla(response.data, response.statusCode);
  }

  // ─── Token İşlemleri ─────────────────────────────────────────────────────

  // Token'ları güvenli depoya kaydeder
  Future<void> _tokenKaydet(String access, String refresh) async {
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
  }

  // Access token'ı okur (API isteklerinde Authorization header'ı için)
  Future<String?> getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }

  // Kullanıcının oturumu açık mı? Token varsa true döner.
  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'access_token');
    return token != null;
  }

  // Çıkış yap — tüm token'ları siler
  Future<void> logout() async {
    await _storage.deleteAll();
  }

  // ─── Yardımcı: Hata Mesajı Ayıkla ───────────────────────────────────────
  // API'den gelen hata response'unu okunabilir bir Türkçe mesaja dönüştürür.
  String _hataAyikla(dynamic data, int? statusCode) {
    // API JSON yerine HTML döndürdüyse (Django hata sayfası) genel mesaj ver
    if (data is String) {
      if (statusCode == 401) return 'Kullanıcı adı veya şifre hatalı.';
      if (statusCode == 400) return 'Geçersiz istek. Bilgilerini kontrol et.';
      return 'Sunucu hatası ($statusCode). Lütfen tekrar dene.';
    }

    // API JSON döndürdüyse 'hata' veya 'detail' anahtarına bak
    if (data is Map<String, dynamic>) {
      if (data.containsKey('hata'))   return data['hata'].toString();
      if (data.containsKey('detail')) return data['detail'].toString();
    }

    return 'Bilinmeyen hata oluştu.';
  }
}
