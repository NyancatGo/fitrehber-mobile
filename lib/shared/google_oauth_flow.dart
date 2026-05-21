import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../core/constants/api_constants.dart';

class GoogleOAuthRequest {
  final String state;
  final String codeVerifier;
  final String codeChallenge;
  final Uri authorizationUrl;

  const GoogleOAuthRequest({
    required this.state,
    required this.codeVerifier,
    required this.codeChallenge,
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

  static GoogleOAuthRequest createRequest({
    String? state,
    String? codeVerifier,
  }) {
    final resolvedState = state ?? _secureToken(32);
    final resolvedVerifier = codeVerifier ?? _secureToken(32);
    final codeChallenge = createCodeChallenge(resolvedVerifier);
    final baseUri = Uri.parse(ApiConstants.webUrl);
    final authorizationUrl = baseUri.replace(
      path: '/accounts/mobile-google/start/',
      queryParameters: {
        'state': resolvedState,
        'code_challenge': codeChallenge,
      },
    );

    return GoogleOAuthRequest(
      state: resolvedState,
      codeVerifier: resolvedVerifier,
      codeChallenge: codeChallenge,
      authorizationUrl: authorizationUrl,
    );
  }

  static String createCodeChallenge(String codeVerifier) {
    final digest = sha256.convert(utf8.encode(codeVerifier)).bytes;
    return _base64UrlNoPadding(digest);
  }

  static GoogleOAuthCallback parseCallback(
    String callbackUrl, {
    required String expectedState,
  }) {
    final uri = Uri.parse(callbackUrl);
    final code = uri.queryParameters['code'];
    final state = uri.queryParameters['state'];

    if (code == null || code.isEmpty) {
      throw const GoogleOAuthException('Google giriş kodu alınamadı.');
    }

    if (state == null || state.isEmpty || state != expectedState) {
      throw const GoogleOAuthException(
        'Google giriş güvenlik doğrulaması başarısız.',
      );
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
}
