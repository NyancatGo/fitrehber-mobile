import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/constants/api_constants.dart';
import 'models/kullanici_model.dart';

class AuthService {
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

  Future<KullaniciModel> login(String username, String password) async {
    final response = await _dio.post(
      ApiConstants.login,
      data: {'username': username, 'password': password},
    );

    if (response.statusCode == 200) {
      return _oturumYanitiKaydet(response.data);
    }

    throw _hataAyikla(response.data, response.statusCode);
  }

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
      return _oturumYanitiKaydet(response.data);
    }

    throw _hataAyikla(response.data, response.statusCode);
  }

  Future<KullaniciModel> exchangeGoogleCode({
    required String code,
    required String state,
    required String codeVerifier,
  }) async {
    final response = await _dio.post(
      ApiConstants.googleToken,
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
    await _tokenKaydet(kullanici.accessToken, kullanici.refreshToken);
    await _kullaniciKaydet(kullaniciJson);
    return kullanici;
  }

  Future<void> _tokenKaydet(String access, String refresh) async {
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
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

  Future<String?> getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'access_token');
    return token != null;
  }

  Future<void> logout() async {
    await _storage.deleteAll();
  }

  // --- Web Google OAuth: bekleyen istek (state + code_verifier) ---
  // Web'de Google'a yönlendirme tüm sayfayı yeniden yüklediği için
  // state ve code_verifier'ı kalıcı depoya yazıp dönüşte okuyoruz.
  static const _googlePendingStateKey = 'google_oauth_pending_state';
  static const _googlePendingVerifierKey = 'google_oauth_pending_verifier';

  Future<void> saveGooglePending({
    required String state,
    required String codeVerifier,
  }) async {
    await _storage.write(key: _googlePendingStateKey, value: state);
    await _storage.write(key: _googlePendingVerifierKey, value: codeVerifier);
  }

  Future<({String state, String codeVerifier})?> readGooglePending() async {
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

  Future<void> clearGooglePending() async {
    await _storage.delete(key: _googlePendingStateKey);
    await _storage.delete(key: _googlePendingVerifierKey);
  }

  String _hataAyikla(dynamic data, int? statusCode) {
    if (data is String) {
      if (statusCode == 401) return 'Kullanıcı adı veya şifre hatalı.';
      if (statusCode == 400) return 'Geçersiz istek. Bilgilerini kontrol et.';
      return 'Sunucu hatası ($statusCode). Lütfen tekrar dene.';
    }

    if (data is Map<String, dynamic>) {
      if (data.containsKey('hata')) return data['hata'].toString();
      if (data.containsKey('detail')) return data['detail'].toString();
    }

    return 'Bilinmeyen hata oluştu.';
  }
}
