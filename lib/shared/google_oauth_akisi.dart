// ---------------------------------------------------------------------------
// GOOGLE İLE GİRİŞ AKIŞI (OAuth 2.0 + PKCE)
// ---------------------------------------------------------------------------
// Google ile giriş işleminin güvenlik adımlarını yönetir. "PKCE" yöntemi
// kullanılır; bu sayede gizli bir anahtar (client secret) uygulama içine
// gömülmeden güvenli giriş yapılabilir.
//
// Akışın özeti:
//  1) `istekOlustur` — rastgele `state` (CSRF koruması) ve `codeVerifier`
//     üretir; bunlardan Google'a gönderilecek `codeChallenge`yi hesaplar.
//  2) Kullanıcı tarayıcıda Google ile giriş yapar.
//  3) Google, uygulamaya bir `code` ile geri döner.
//  4) `donusuCoz` / `webDonusunuCoz` bu dönüşü çözer ve `state`
//     eşleşmesini doğrular (sahte/araya girilmiş dönüşleri reddeder).
// ---------------------------------------------------------------------------

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/api_sabitleri.dart';

/// Google'a gönderilmeden önce hazırlanan OAuth giriş isteğini temsil eder.
class GoogleOAuthIstegi {
  /// CSRF saldırılarına karşı rastgele üretilen tek kullanımlık değer.
  final String state;

  /// PKCE doğrulayıcısı — uygulamada saklanır, token alırken sunucuya gönderilir.
  final String codeVerifier;

  /// `codeVerifier`in SHA-256 özeti — Google'a gönderilen kısım.
  final String codeChallenge;

  /// Backend'in OAuth dönüşünü göndereceği adres.
  /// Native'de `fitrehber://oauth/callback`, web'de uygulamanın kendi URL'i.
  final String redirectUri;
  final Uri authorizationUrl;

  const GoogleOAuthIstegi({
    required this.state,
    required this.codeVerifier,
    required this.codeChallenge,
    required this.redirectUri,
    required this.authorizationUrl,
  });
}

/// Google'dan dönen yanıtı (yetkilendirme kodu + state) temsil eder.
class GoogleOAuthDonusu {
  /// Google'ın verdiği tek kullanımlık yetkilendirme kodu.
  final String code;

  /// İstekle birlikte gönderilen, dönüşte aynen geri gelen güvenlik değeri.
  final String state;

  const GoogleOAuthDonusu({required this.code, required this.state});
}

/// Google giriş akışında oluşan hataları temsil eden özel istisna sınıfı.
class GoogleOAuthHatasi implements Exception {
  /// Kullanıcıya gösterilebilecek hata mesajı.
  final String message;

  const GoogleOAuthHatasi(this.message);

  @override
  String toString() => message;
}

/// Google OAuth giriş akışının tüm adımlarını yürüten yardımcı sınıf.
class GoogleOAuthAkisi {
  static const donusSemasi = 'fitrehber';
  static const donusHostu = 'oauth';
  static const donusYolu = '/callback';

  /// Native uygulamanın deep link dönüş adresi.
  static const nativeDonusAdresi = '$donusSemasi://$donusHostu$donusYolu';

  /// Yeni bir Google giriş isteği hazırlar (state + PKCE değerleri + URL).
  static GoogleOAuthIstegi istekOlustur({String? state, String? codeVerifier}) {
    final resolvedState = state ?? _secureToken(32);
    final resolvedVerifier = codeVerifier ?? _secureToken(32);
    final codeChallenge = kodChallengeOlustur(resolvedVerifier);
    final redirectUri = _resolveRedirectUri();
    final baseUri = Uri.parse(ApiSabitleri.webUrl);
    final authorizationUrl = baseUri.replace(
      path: '/accounts/mobile-google/start/',
      queryParameters: {
        'state': resolvedState,
        'code_challenge': codeChallenge,
        'redirect_uri': redirectUri,
      },
    );

    return GoogleOAuthIstegi(
      state: resolvedState,
      codeVerifier: resolvedVerifier,
      codeChallenge: codeChallenge,
      redirectUri: redirectUri,
      authorizationUrl: authorizationUrl,
    );
  }

  /// Çalışılan platforma göre OAuth dönüş adresini belirler.
  /// Native → deep link; web → uygulamanın barındığı URL.
  static String _resolveRedirectUri() {
    if (!kIsWeb) return nativeDonusAdresi;
    return webDonusAdresiOlustur(Uri.base);
  }

  /// Verilen URL'den (query/fragment atılarak) web uygulamasının
  /// temel adresini üretir. OAuth dönüşünün geleceği hedeftir.
  static String webDonusAdresiOlustur(Uri base) {
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.port,
      path: base.path.isEmpty ? '/' : base.path,
    ).toString();
  }

  /// Web akışında OAuth dönüşünü çözümler: URL'de `code` ve `state` query
  /// parametreleri varsa callback döner, yoksa null.
  static GoogleOAuthDonusu? webDonusunuCoz(Uri uri) {
    final code = uri.queryParameters['code'];
    final state = uri.queryParameters['state'];
    if (code == null || code.isEmpty || state == null || state.isEmpty) {
      return null;
    }
    return GoogleOAuthDonusu(code: code, state: state);
  }

  /// `codeVerifier`den, Google'a gönderilecek `codeChallenge`yi (SHA-256) üretir.
  static String kodChallengeOlustur(String codeVerifier) {
    final digest = sha256.convert(utf8.encode(codeVerifier)).bytes;
    return _base64UrlNoPadding(digest);
  }

  /// Native (mobil) deep link dönüşünü çözümler ve güvenlik kontrollerini yapar.
  ///
  /// `state` beklenenle eşleşmezse veya kod yoksa `GoogleOAuthHatasi` fırlatır.
  static GoogleOAuthDonusu donusuCoz(
    String callbackUrl, {
    required String expectedState,
  }) {
    final uri = Uri.tryParse(callbackUrl);
    if (uri == null || uri.scheme != donusSemasi) {
      throw const GoogleOAuthHatasi('Geçersiz Google dönüş adresi.');
    }

    final parameters = {
      ...uri.queryParameters,
      ..._fragmentParameters(uri.fragment),
    };
    final state = parameters['state'];

    if (state == null || state.isEmpty || state != expectedState) {
      throw const GoogleOAuthHatasi(
        'Google giriş güvenlik doğrulaması başarısız.',
      );
    }

    final oauthError = parameters['error'];
    if (oauthError != null && oauthError.isNotEmpty) {
      throw GoogleOAuthHatasi(
        _oauthErrorMessage(oauthError, parameters['error_description']),
      );
    }

    final code = parameters['code'];
    if (code == null || code.isEmpty) {
      throw const GoogleOAuthHatasi('Google giriş kodu alınamadı.');
    }

    return GoogleOAuthDonusu(code: code, state: state);
  }

  static String _secureToken(int byteLength) {
    final random = Random.secure();
    final bytes = List<int>.generate(byteLength, (_) => random.nextInt(256));
    return _base64UrlNoPadding(bytes);
  }

  static String _base64UrlNoPadding(List<int> bytes) {
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static Map<String, String> _fragmentParameters(String fragment) {
    if (fragment.isEmpty || !fragment.contains('=')) return const {};
    return Uri.splitQueryString(fragment);
  }

  static String _oauthErrorMessage(String error, String? description) {
    final normalizedDescription = description?.trim();
    if (normalizedDescription != null && normalizedDescription.isNotEmpty) {
      return normalizedDescription;
    }

    if (error == 'access_denied') {
      return 'Google giriş işlemi iptal edildi.';
    }

    return 'Google giriş işlemi tamamlanamadı ($error).';
  }
}
