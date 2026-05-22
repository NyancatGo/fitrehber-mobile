import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/api_constants.dart';

class GoogleOAuthRequest {
  final String state;
  final String codeVerifier;
  final String codeChallenge;

  /// Backend'in OAuth dönüşünü göndereceği adres.
  /// Native'de `fitrehber://oauth/callback`, web'de uygulamanın kendi URL'i.
  final String redirectUri;
  final Uri authorizationUrl;

  const GoogleOAuthRequest({
    required this.state,
    required this.codeVerifier,
    required this.codeChallenge,
    required this.redirectUri,
    required this.authorizationUrl,
  });
}

class GoogleOAuthCallback {
  final String code;
  final String state;

  const GoogleOAuthCallback({required this.code, required this.state});
}

class GoogleOAuthException implements Exception {
  final String message;

  const GoogleOAuthException(this.message);

  @override
  String toString() => message;
}

class GoogleOAuthFlow {
  static const callbackScheme = 'fitrehber';
  static const callbackHost = 'oauth';
  static const callbackPath = '/callback';

  /// Native uygulamanın deep link dönüş adresi.
  static const nativeRedirectUri =
      '$callbackScheme://$callbackHost$callbackPath';

  static GoogleOAuthRequest createRequest({
    String? state,
    String? codeVerifier,
  }) {
    final resolvedState = state ?? _secureToken(32);
    final resolvedVerifier = codeVerifier ?? _secureToken(32);
    final codeChallenge = createCodeChallenge(resolvedVerifier);
    final redirectUri = _resolveRedirectUri();
    final baseUri = Uri.parse(ApiConstants.webUrl);
    final authorizationUrl = baseUri.replace(
      path: '/accounts/mobile-google/start/',
      queryParameters: {
        'state': resolvedState,
        'code_challenge': codeChallenge,
        'redirect_uri': redirectUri,
      },
    );

    return GoogleOAuthRequest(
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
    if (!kIsWeb) return nativeRedirectUri;
    return webRedirectUriFor(Uri.base);
  }

  /// Verilen URL'den (query/fragment atılarak) web uygulamasının
  /// temel adresini üretir. OAuth dönüşünün geleceği hedeftir.
  static String webRedirectUriFor(Uri base) {
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.port,
      path: base.path.isEmpty ? '/' : base.path,
    ).toString();
  }

  /// Web akışında OAuth dönüşünü çözümler: URL'de `code` ve `state` query
  /// parametreleri varsa callback döner, yoksa null.
  static GoogleOAuthCallback? webCallbackFromUri(Uri uri) {
    final code = uri.queryParameters['code'];
    final state = uri.queryParameters['state'];
    if (code == null || code.isEmpty || state == null || state.isEmpty) {
      return null;
    }
    return GoogleOAuthCallback(code: code, state: state);
  }

  static String createCodeChallenge(String codeVerifier) {
    final digest = sha256.convert(utf8.encode(codeVerifier)).bytes;
    return _base64UrlNoPadding(digest);
  }

  static GoogleOAuthCallback parseCallback(
    String callbackUrl, {
    required String expectedState,
  }) {
    final uri = Uri.tryParse(callbackUrl);
    if (uri == null || uri.scheme != callbackScheme) {
      throw const GoogleOAuthException('Geçersiz Google dönüş adresi.');
    }

    final parameters = {
      ...uri.queryParameters,
      ..._fragmentParameters(uri.fragment),
    };
    final state = parameters['state'];

    if (state == null || state.isEmpty || state != expectedState) {
      throw const GoogleOAuthException(
        'Google giriş güvenlik doğrulaması başarısız.',
      );
    }

    final oauthError = parameters['error'];
    if (oauthError != null && oauthError.isNotEmpty) {
      throw GoogleOAuthException(
        _oauthErrorMessage(oauthError, parameters['error_description']),
      );
    }

    final code = parameters['code'];
    if (code == null || code.isEmpty) {
      throw const GoogleOAuthException('Google giriş kodu alınamadı.');
    }

    return GoogleOAuthCallback(code: code, state: state);
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
