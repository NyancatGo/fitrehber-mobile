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
// ---------------------------------------------------------------------------

import 'package:fitrehber_mobile/core/constants/api_sabitleri.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiSabitleri kök adresleri', () {
    test('baseUrl ve webUrl beklenen değerlerde', () {
      expect(ApiSabitleri.baseUrl, 'https://api.fitrehber.com.tr/api');
      expect(ApiSabitleri.webUrl, 'https://fitrehber.com.tr');
    });
  });

  group('ApiSabitleri kimlik doğrulama uç noktaları', () {
    test('girisYap adresi /auth/login/ olmalı (Türkçeleşmemeli)', () {
      expect(
        ApiSabitleri.girisYap,
        'https://api.fitrehber.com.tr/api/auth/login/',
      );
    });

    test('kayitOl adresi /mobile/auth/register/ olmalı (Türkçeleşmemeli)', () {
      expect(
        ApiSabitleri.kayitOl,
        'https://fitrehber.com.tr/mobile/auth/register/',
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
  });

  group('ApiSabitleri parametreli (dinamik) uç noktalar', () {
    test('profilDetay doğru adresi üretir', () {
      expect(
        ApiSabitleri.profilDetay(42),
        'https://api.fitrehber.com.tr/api/profil/42/',
      );
    });

    test('yorumlar doğru adresi üretir', () {
      expect(
        ApiSabitleri.yorumlar(7),
        'https://api.fitrehber.com.tr/api/icerikler/7/yorumlar/',
      );
    });

    test('beslenmeGuncelle doğru adresi üretir', () {
      expect(
        ApiSabitleri.beslenmeGuncelle(13),
        'https://api.fitrehber.com.tr/api/beslenme/guncelle/13/',
      );
    });
  });

  group('ApiSabitleri beslenme senkron uç noktaları', () {
    test('besinlerSync canonical sync adresidir', () {
      expect(
        ApiSabitleri.besinlerSync,
        'https://api.fitrehber.com.tr/api/besinler/sync/',
      );
    });

    test('kopyala ve son besinler web parite adreslerini kullanır', () {
      expect(
        ApiSabitleri.beslenmeKopyala,
        'https://api.fitrehber.com.tr/api/beslenme/kopyala/',
      );
      expect(
        ApiSabitleri.sonBesinler,
        'https://api.fitrehber.com.tr/api/beslenme/son-besinler/',
      );
    });
  });
}
