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
}
