import 'package:fitrehber_mobile/shared/google_oauth_akisi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'istekOlustur, state ve challenge içeren web başlangıç adresini üretir',
    () {
      final istek = GoogleOAuthAkisi.istekOlustur(
        state: 'state-token-abcdefghijklmnopqrstuvwxyz',
        codeVerifier: 'verifier-token',
      );

      expect(istek.codeChallenge, hasLength(43));
      expect(istek.authorizationUrl.scheme, 'https');
      expect(istek.authorizationUrl.host, 'fitrehber.com.tr');
      expect(istek.authorizationUrl.path, '/accounts/mobile-google/start/');
      expect(
        istek.authorizationUrl.queryParameters['state'],
        'state-token-abcdefghijklmnopqrstuvwxyz',
      );
      expect(
        istek.authorizationUrl.queryParameters['code_challenge'],
        istek.codeChallenge,
      );
    },
  );

  test('donusuCoz, state eşleştiğinde kodu döndürür', () {
    final donus = GoogleOAuthAkisi.donusuCoz(
      'fitrehber://oauth/callback?code=abc123&state=state-token',
      expectedState: 'state-token',
    );

    expect(donus.code, 'abc123');
    expect(donus.state, 'state-token');
  });

  test('donusuCoz, state uyuşmazlığını reddeder', () {
    expect(
      () => GoogleOAuthAkisi.donusuCoz(
        'fitrehber://oauth/callback?code=abc123&state=attacker-state',
        expectedState: 'state-token',
      ),
      throwsA(isA<GoogleOAuthHatasi>()),
    );
  });

  test('donusuCoz, uygulamaya ait olmayan dönüş adreslerini reddeder', () {
    expect(
      () => GoogleOAuthAkisi.donusuCoz(
        'https://fitrehber.com.tr/oauth/callback?code=abc123&state=state-token',
        expectedState: 'state-token',
      ),
      throwsA(isA<GoogleOAuthHatasi>()),
    );
  });

  test('donusuCoz, state doğrulamasından sonra OAuth hatalarını bildirir', () {
    expect(
      () => GoogleOAuthAkisi.donusuCoz(
        'fitrehber://oauth/callback?error=access_denied&state=state-token',
        expectedState: 'state-token',
      ),
      throwsA(
        isA<GoogleOAuthHatasi>().having(
          (error) => error.message,
          'message',
          'Google giriş işlemi iptal edildi.',
        ),
      ),
    );
  });

  test('donusuCoz, fragment parametrelerini kabul eder', () {
    final donus = GoogleOAuthAkisi.donusuCoz(
      'fitrehber://oauth/callback#code=abc123&state=state-token',
      expectedState: 'state-token',
    );

    expect(donus.code, 'abc123');
    expect(donus.state, 'state-token');
  });

  test('istekOlustur, redirect_uri taşır (testlerde native deep link)', () {
    final istek = GoogleOAuthAkisi.istekOlustur(
      state: 'state-token-abcdefghijklmnopqrstuvwxyz',
      codeVerifier: 'verifier-token',
    );

    // flutter test ortamında kIsWeb=false → native deep link kullanılır.
    expect(istek.redirectUri, GoogleOAuthAkisi.nativeDonusAdresi);
    expect(GoogleOAuthAkisi.nativeDonusAdresi, 'fitrehber://oauth/callback');
    expect(
      istek.authorizationUrl.queryParameters['redirect_uri'],
      GoogleOAuthAkisi.nativeDonusAdresi,
    );
  });

  test('webDonusAdresiOlustur, query ve fragment\'i atar, path\'i korur', () {
    expect(
      GoogleOAuthAkisi.webDonusAdresiOlustur(
        Uri.parse('http://localhost:58442/#/giris'),
      ),
      'http://localhost:58442/',
    );
    expect(
      GoogleOAuthAkisi.webDonusAdresiOlustur(
        Uri.parse('https://app.fitrehber.com.tr/app/?code=x#/giris'),
      ),
      'https://app.fitrehber.com.tr/app/',
    );
  });

  test('webDonusunuCoz, varsa code ve state döndürür', () {
    final donus = GoogleOAuthAkisi.webDonusunuCoz(
      Uri.parse('http://localhost:58442/?code=abc123&state=state-token'),
    );

    expect(donus, isNotNull);
    expect(donus!.code, 'abc123');
    expect(donus.state, 'state-token');
  });

  test('webDonusunuCoz, parametreler eksikse null döndürür', () {
    expect(
      GoogleOAuthAkisi.webDonusunuCoz(Uri.parse('http://localhost:58442/')),
      isNull,
    );
    expect(
      GoogleOAuthAkisi.webDonusunuCoz(
        Uri.parse('http://localhost:58442/?code=only-code'),
      ),
      isNull,
    );
  });
}
