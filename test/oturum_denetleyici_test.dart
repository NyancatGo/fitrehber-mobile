// OturumDenetleyici profil yükleme davranışı:
//   - HTTP auth hatası (String/Exception) -> oturum sonlandırılmalı (cikisYap)
//   - DioException ağ hatası -> oturum KORUNMALI, profil önbellekten/boş gelmeli
//
// Antigravity Faz 2 #5 regresyon testi: çevrimdışıyken uygulama açılırken
// kullanıcı zorla çıkışa atılmamalı.

import 'package:dio/dio.dart';
import 'package:fitrehber_mobile/shared/api_servisi.dart';
import 'package:fitrehber_mobile/shared/kimlik_servisi.dart';
import 'package:fitrehber_mobile/shared/models/profil_model.dart';
import 'package:fitrehber_mobile/shared/oturum_denetleyici.dart';
import 'package:flutter_test/flutter_test.dart';

class _SahteApiServisi extends ApiServisi {
  _SahteApiServisi(this._hata);
  final Object _hata;

  @override
  Future<ProfilModel> profiliGetir() async => throw _hata;
}

class _SayimliKimlikServisi extends KimlikServisi {
  int cikisSayisi = 0;

  @override
  Future<String?> accessTokenOku() async => 'fake-token';

  @override
  Future<void> cikisYap() async {
    cikisSayisi += 1;
  }
}

class _KayitKimlikServisi extends _SayimliKimlikServisi {
  List<String>? kayitArgumanlari;

  @override
  Future<void> kayitOl(
    String username,
    String password,
    String email,
    String password2,
  ) async {
    kayitArgumanlari = [username, password, email, password2];
  }
}

void main() {
  test(
    'oturumuGeriYukle() DioException durumunda oturumu korur (offline)',
    () async {
      final dioErr = DioException(
        requestOptions: RequestOptions(path: '/api/profil/'),
        type: DioExceptionType.connectionError,
        message: 'Connection failed',
      );
      final kimlik = _SayimliKimlikServisi();
      final api = _SahteApiServisi(dioErr);
      final denetleyici = OturumDenetleyici(
        kimlikServisi: kimlik,
        apiServisi: api,
      );

      await denetleyici.oturumuGeriYukle();

      // Çıkış çağrılmamalı; state oturum açık kalmalı.
      expect(kimlik.cikisSayisi, 0);
      expect(denetleyici.state.oturumVarMi, true);
      // Profil cache yoktu, boş profil yedeği kullanıldı.
      expect(denetleyici.state.profile, isNotNull);
      // Hata mesajı set edilmiş olmalı (kullanıcıyı bilgilendirmek için).
      expect(denetleyici.state.error, isNotNull);
    },
  );

  test('oturumuGeriYukle() gerçek auth hatasında çıkış yaptırır', () async {
    // ApiServisi gerçek 401 durumunda String fırlatır.
    const authErr = 'Oturum süren doldu.';
    final kimlik = _SayimliKimlikServisi();
    final api = _SahteApiServisi(authErr);
    final denetleyici = OturumDenetleyici(
      kimlikServisi: kimlik,
      apiServisi: api,
    );

    await denetleyici.oturumuGeriYukle();

    // Auth hatası -> cikisYap çağrılmalı.
    expect(kimlik.cikisSayisi, 1);
    expect(denetleyici.state.oturumVarMi, false);
  });

  test(
    'kayitOl() parola tekrarını gönderir ve eski oturumu temizler',
    () async {
      final kimlik = _KayitKimlikServisi();
      final api = _SahteApiServisi('unused');
      final denetleyici = OturumDenetleyici(
        kimlikServisi: kimlik,
        apiServisi: api,
      );
      denetleyici.state = OturumDurumu(
        isLoading: false,
        oturumVarMi: true,
        profile: ProfilModel.empty(),
      );

      await denetleyici.kayitOl(
        'newuser',
        'CorrectPass123!',
        'new@example.com',
        'CorrectPass123!',
      );

      expect(kimlik.kayitArgumanlari, [
        'newuser',
        'CorrectPass123!',
        'new@example.com',
        'CorrectPass123!',
      ]);
      expect(kimlik.cikisSayisi, 1);
      expect(denetleyici.state.isLoading, false);
      expect(denetleyici.state.oturumVarMi, false);
      expect(denetleyici.state.profile, isNull);
    },
  );
}
