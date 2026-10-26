// ---------------------------------------------------------------------------
// API SABİTLERİ — UÇ NOKTA REGRESYON TESTLERİ
// ---------------------------------------------------------------------------
// Bu test dosyasının amacı: Türkçeleştirme/yeniden adlandırma turlarında
// backend uç nokta adreslerinin yanlışlıkla bozulmasını engellemek.
//
// Geçmişte kör bir "ara-değiştir" işlemi, `login` -> `girisYap` çevirisini
// URL string'inin İÇİNE de uygulayıp `/auth/login/` adresini `/auth/girisYap/`
// yapmıştı. Değişken adı Türkçe olabilir; ancak URL'nin kendisi backend
// sözleşmesidir ve aynen kalmalıdır. Bu testler tam olarak bunu denetler.
//
// ORTAM BAĞIMSIZLIK
// ------------------
// Adresler artık `--dart-define=API_BASE_URL=...` ile değiştirilebiliyor.
// Bu yüzden testlerde DOMAIN sabit kodlanmaz; sözleşmenin kendisi olan
// YOL (path) denetlenir. Böylece test paketi hem üretimde hem de staging/
// CI adresleriyle koşabilir.
// ---------------------------------------------------------------------------

import 'package:fitrehber_mobile/core/constants/api_sabitleri.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiSabitleri kök adresleri', () {
    test('baseUrl ve webUrl varsayılan olarak üretim adreslerinde', () {
      // Tanım verilmediğinde (normal CI koşusu) üretim adresi beklenir.
      const tanimli = String.fromEnvironment('API_BASE_URL');
      if (tanimli.isEmpty) {
        expect(ApiSabitleri.baseUrl, 'https://api.fitrehber.com.tr/api');
      } else {
        expect(ApiSabitleri.baseUrl, tanimli);
      }

      const webTanimli = String.fromEnvironment('WEB_BASE_URL');
      if (webTanimli.isEmpty) {
        expect(ApiSabitleri.webUrl, 'https://fitrehber.com.tr');
      } else {
        expect(ApiSabitleri.webUrl, webTanimli);
      }
    });

    test('kendi profil ucu kullanici id icermez', () {
      // Id JWT icinden sunucuda belirlenir; istemci JWT cozmez.
      expect(ApiSabitleri.profil, '${ApiSabitleri.baseUrl}/profil/');
    });
  });

  group('ApiSabitleri kimlik doğrulama uç noktaları', () {
    test('girisYap adresi /auth/login/ olmalı (Türkçeleşmemeli)', () {
      expect(ApiSabitleri.girisYap, '${ApiSabitleri.baseUrl}/auth/login/');
    });

    test('kayitOl adresi /mobile/auth/register/ olmalı (Türkçeleşmemeli)', () {
      expect(
        ApiSabitleri.kayitOl,
        '${ApiSabitleri.webUrl}/mobile/auth/register/',
      );
    });

    test('dogrulamaMailiTekrarGonder doğru doğrulama adresiyle biter', () {
      expect(
        ApiSabitleri.dogrulamaMailiTekrarGonder,
        endsWith('/mobile/auth/verification/resend/'),
      );
    });

    test('sifreSifirlamaIste doğru şifre sıfırlama adresiyle biter', () {
      expect(
        ApiSabitleri.sifreSifirlamaIste,
        endsWith('/mobile/auth/password-reset/request/'),
      );
    });

    test('tokenRefresh doğru yenileme adresiyle biter', () {
      expect(ApiSabitleri.tokenRefresh, endsWith('/auth/token/refresh/'));
    });

    test('googleToken doğru Google token adresiyle biter', () {
      expect(ApiSabitleri.googleToken, endsWith('/auth/google/token/'));
    });

    test('profilOnboard doğru ilk kurulum adresiyle biter', () {
      expect(ApiSabitleri.profilOnboard, endsWith('/profil/onboard/'));
    });
  });

  group('ApiSabitleri uç noktaları Türkçeye kaymamış olmalı', () {
    // Adreslerde bozulmuş Türkçe yol parçaları (girisYap, kayitOl, cikis...)
    // KESİNLİKLE bulunmamalı. Bu, regresyona karşı son emniyet kemeridir.
    final tumAdresler = <String>[
      ApiSabitleri.girisYap,
      ApiSabitleri.kayitOl,
      ApiSabitleri.dogrulamaMailiTekrarGonder,
      ApiSabitleri.sifreSifirlamaIste,
      ApiSabitleri.tokenRefresh,
      ApiSabitleri.googleToken,
      ApiSabitleri.kategoriler,
      ApiSabitleri.icerikler,
      ApiSabitleri.profil,
      ApiSabitleri.profilOnboard,
      ApiSabitleri.beslenmeSu,
      ApiSabitleri.besinler,
      ApiSabitleri.besinlerSync,
      ApiSabitleri.beslenmeEkle,
      ApiSabitleri.beslenmeKopyala,
      ApiSabitleri.sonBesinler,
      ApiSabitleri.aiChat,
    ];

    test('hiçbir adres bozuk Türkçe yol parçası içermez', () {
      for (final adres in tumAdresler) {
        expect(adres.contains('auth/giris'), isFalse, reason: adres);
        expect(adres.contains('mobile/auth/kayit'), isFalse, reason: adres);
        expect(adres.contains('auth/cikis'), isFalse, reason: adres);
      }
    });

    test('tum adresler http(s) ile baslar', () {
      for (final adres in tumAdresler) {
        expect(
          adres.startsWith('http://') || adres.startsWith('https://'),
          isTrue,
          reason: adres,
        );
      }
    });
  });

  group('ApiSabitleri parametreli (dinamik) uç noktalar', () {
    test('profilDetay doğru adresi üretir', () {
      expect(
        ApiSabitleri.profilDetay(42),
        '${ApiSabitleri.baseUrl}/profil/42/',
      );
    });

    test('yorumlar doğru adresi üretir', () {
      expect(
        ApiSabitleri.yorumlar(7),
        '${ApiSabitleri.baseUrl}/icerikler/7/yorumlar/',
      );
    });

    test('beslenmeGuncelle doğru adresi üretir', () {
      expect(
        ApiSabitleri.beslenmeGuncelle(13),
        '${ApiSabitleri.baseUrl}/beslenme/guncelle/13/',
      );
    });
  });

  group('ApiSabitleri beslenme senkron uç noktaları', () {
    test('besinlerSync canonical sync adresidir', () {
      expect(
        ApiSabitleri.besinlerSync,
        '${ApiSabitleri.baseUrl}/besinler/sync/',
      );
    });

    test('kopyala ve son besinler web parite adreslerini kullanır', () {
      expect(
        ApiSabitleri.beslenmeKopyala,
        '${ApiSabitleri.baseUrl}/beslenme/kopyala/',
      );
      expect(
        ApiSabitleri.sonBesinler,
        '${ApiSabitleri.baseUrl}/beslenme/son-besinler/',
      );
    });
  });

  group('ApiSabitleri medya URL normalizasyonu', () {
    test('mediaUrlNormalize webUrl tabanını kullanarak göreli yolları çözer', () {
      expect(ApiSabitleri.mediaUrlNormalize(null), isNull);
      expect(ApiSabitleri.mediaUrlNormalize('   '), isNull);
      expect(
        ApiSabitleri.mediaUrlNormalize('/media/profil_fotograflari/a.webp'),
        '${ApiSabitleri.webUrl}/media/profil_fotograflari/a.webp',
      );
      expect(
        ApiSabitleri.mediaUrlNormalize('media/icerik_resimleri/b.webp'),
        '${ApiSabitleri.webUrl}/media/icerik_resimleri/b.webp',
      );
      expect(
        ApiSabitleri.mediaUrlNormalize('profil_fotograflari/c.webp'),
        '${ApiSabitleri.webUrl}/media/profil_fotograflari/c.webp',
      );
      expect(
        ApiSabitleri.mediaUrlNormalize('//cdn.example.com/img.png'),
        'https://cdn.example.com/img.png',
      );
      expect(
        ApiSabitleri.mediaUrlNormalize('https://cdn.example.com/img.png'),
        'https://cdn.example.com/img.png',
      );
    });
  });
}
