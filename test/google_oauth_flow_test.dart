import 'package:fitrehber_mobile/shared/google_oauth_flow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('createRequest builds web start URL with state and challenge', () {
    final request = GoogleOAuthFlow.createRequest(
      state: 'state-token-abcdefghijklmnopqrstuvwxyz',
      codeVerifier: 'verifier-token',
    );

    expect(request.codeChallenge, hasLength(43));
    expect(request.authorizationUrl.scheme, 'https');
    expect(request.authorizationUrl.host, 'fitrehber.com.tr');
    expect(request.authorizationUrl.path, '/accounts/mobile-google/start/');
    expect(
      request.authorizationUrl.queryParameters['state'],
      'state-token-abcdefghijklmnopqrstuvwxyz',
    );
    expect(
      request.authorizationUrl.queryParameters['code_challenge'],
      request.codeChallenge,
    );
  });

  test('parseCallback returns code when state matches', () {
    final callback = GoogleOAuthFlow.parseCallback(
      'fitrehber://oauth/callback?code=abc123&state=state-token',
      expectedState: 'state-token',
    );

    expect(callback.code, 'abc123');
    expect(callback.state, 'state-token');
  });

  test('parseCallback rejects state mismatch', () {
    expect(
      () => GoogleOAuthFlow.parseCallback(
        'fitrehber://oauth/callback?code=abc123&state=attacker-state',
        expectedState: 'state-token',
      ),
      throwsA(isA<GoogleOAuthException>()),
    );
  });

  test('parseCallback rejects non app callback URLs', () {
    expect(
      () => GoogleOAuthFlow.parseCallback(
        'https://fitrehber.com.tr/oauth/callback?code=abc123&state=state-token',
        expectedState: 'state-token',
      ),
      throwsA(isA<GoogleOAuthException>()),
    );
  });

  test('parseCallback surfaces OAuth errors after state validation', () {
    expect(
      () => GoogleOAuthFlow.parseCallback(
        'fitrehber://oauth/callback?error=access_denied&state=state-token',
        expectedState: 'state-token',
      ),
      throwsA(
        isA<GoogleOAuthException>().having(
          (error) => error.message,
          'message',
          'Google giriş işlemi iptal edildi.',
        ),
      ),
    );
  });

  test('parseCallback accepts fragment parameters', () {
    final callback = GoogleOAuthFlow.parseCallback(
      'fitrehber://oauth/callback#code=abc123&state=state-token',
      expectedState: 'state-token',
    );

    expect(callback.code, 'abc123');
    expect(callback.state, 'state-token');
  });

  test('createRequest carries redirect_uri (native deep link in tests)', () {
    final request = GoogleOAuthFlow.createRequest(
      state: 'state-token-abcdefghijklmnopqrstuvwxyz',
      codeVerifier: 'verifier-token',
    );

    // flutter test ortamında kIsWeb=false → native deep link kullanılır.
    expect(request.redirectUri, GoogleOAuthFlow.nativeRedirectUri);
    expect(GoogleOAuthFlow.nativeRedirectUri, 'fitrehber://oauth/callback');
    expect(
      request.authorizationUrl.queryParameters['redirect_uri'],
      GoogleOAuthFlow.nativeRedirectUri,
    );
  });

  test('webRedirectUriFor strips query and fragment, keeps path', () {
    expect(
      GoogleOAuthFlow.webRedirectUriFor(
        Uri.parse('http://localhost:58442/#/giris'),
      ),
      'http://localhost:58442/',
    );
    expect(
      GoogleOAuthFlow.webRedirectUriFor(
        Uri.parse('https://app.fitrehber.com.tr/app/?code=x#/giris'),
      ),
      'https://app.fitrehber.com.tr/app/',
    );
  });

  test('webCallbackFromUri returns code and state when present', () {
    final callback = GoogleOAuthFlow.webCallbackFromUri(
      Uri.parse('http://localhost:58442/?code=abc123&state=state-token'),
    );

    expect(callback, isNotNull);
    expect(callback!.code, 'abc123');
    expect(callback.state, 'state-token');
  });

  test('webCallbackFromUri returns null when params are missing', () {
    expect(
      GoogleOAuthFlow.webCallbackFromUri(Uri.parse('http://localhost:58442/')),
      isNull,
    );
    expect(
      GoogleOAuthFlow.webCallbackFromUri(
        Uri.parse('http://localhost:58442/?code=only-code'),
      ),
      isNull,
    );
  });
}
