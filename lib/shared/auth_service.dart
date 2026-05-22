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

  Future<void> register(
    String username,
    String password,
    String email,
    String password2,
  ) async {
    final response = await _dio.post(
      ApiConstants.register,
      data: {
        'username': username,
        'email': email,
        'password': password,
        'password2': password2,
      },
    );

    if (response.statusCode == 201) {
      return; // Başarılı, doğrulama e-postası gönderildi.
    }

    throw _hataAyikla(response.data, response.statusCode);
  }

  Future<void> resendVerification(String email) async {
    final response = await _dio.post(
      ApiConstants.resendVerification,
      data: {'email': email},
    );

    if (response.statusCode == 200) {
      return;
    }

    throw _hataAyikla(response.data, response.statusCode);
  }

  Future<void> passwordResetRequest(String email) async {
    final response = await _dio.post(
      ApiConstants.passwordResetRequest,
      data: {'email': email},
    );

    if (response.statusCode == 200) {
      return;
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

  // --- Access token yenileme ---
  // Access token 1 gun, refresh token 30 gun yasiyor. Access token suresi
  // dolunca (API 401) refresh token ile yeni access token alinir; boylece
  // kullanici "durduk yere uygulamadan atildi" yasamaz.
  //
  // Single-flight: ayni anda birden cok istek 401 alirsa tek bir refresh
  // cagrisi yapilir, hepsi ayni Future'i bekler.
  Future<bool>? _refreshInFlight;

  Future<bool> refreshAccessToken() {
    return _refreshInFlight ??= _performTokenRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<bool> _performTokenRefresh() async {
    final refresh = await _storage.read(key: 'refresh_token');
    if (refresh == null || refresh.isEmpty) return false;

    try {
      final response = await _dio.post(
        ApiConstants.tokenRefresh,
        data: {'refresh': refresh},
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map;
        final access = data['access']?.toString();
        if (access == null || access.isEmpty) return false;

        await _storage.write(key: 'access_token', value: access);
        // ROTATE_REFRESH_TOKENS=True → sunucu yeni bir refresh token da
        // dondurebilir; varsa kalici depoyu guncelle.
        final newRefresh = data['refresh']?.toString();
        if (newRefresh != null && newRefresh.isNotEmpty) {
          await _storage.write(key: 'refresh_token', value: newRefresh);
        }
        return true;
      }
      return false;
    } catch (_) {
      // Ag hatasi vb. — refresh basarisiz, cagiran taraf logout'a karar verir.
      return false;
    }
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
      if (statusCode == 403) return 'Bu işlem için izniniz yok.';
      if (statusCode == 400) return 'Geçersiz istek. Bilgilerini kontrol et.';
      return 'Sunucu hatası ($statusCode). Lütfen tekrar dene.';
    }

    if (data is Map) {
      if (data['code'] == 'email_verification_required') {
        throw EmailVerificationRequiredException(
          data['email']?.toString() ?? '',
        );
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

class EmailVerificationRequiredException implements Exception {
  final String email;
  EmailVerificationRequiredException(this.email);

  @override
  String toString() => 'E-posta doğrulaması gerekiyor.';
}
