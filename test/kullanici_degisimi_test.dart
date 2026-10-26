// ---------------------------------------------------------------------------
// KULLANICI DEĞİŞİMİNDE SAĞLAYICI YENİDEN KURULMASI
// ---------------------------------------------------------------------------
// Asistan ve beslenme denetleyicileri oturumdaki kullanıcı kimliğini İZLER
// (`ref.watch(oturumDenetleyiciProvider.select((s) => s.profile?.id))`).
// Böylece çıkışta (id -> null) veya hesap değişiminde (id A -> B) denetleyici
// atılıp yeniden oluşturulur.
//
// Neden önemli?
//   A'nın sohbeti bellekte kalıp B'ye gösterilirse (veya B bir mesaj
//   gönderdiğinde kalıcı geçmiş dosyasına A'nın mesajları yazılırsa) bu bir
//   hesaplar arası sızıntıdır. Güvence, çıkış hangi yoldan yapılırsa yapılsın
//   (profil ekranı, zorunlu oturum sonlandırma, token hatası) sağlanmalıdır.
// ---------------------------------------------------------------------------

import 'package:fitrehber_mobile/features/asistan/providers/asistan_provider.dart';
import 'package:fitrehber_mobile/features/beslenme/providers/beslenme_provider.dart';
import 'package:fitrehber_mobile/shared/api_servisi.dart';
import 'package:fitrehber_mobile/shared/kimlik_servisi.dart';
import 'package:fitrehber_mobile/shared/models/profil_model.dart';
import 'package:fitrehber_mobile/shared/oturum_denetleyici.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Testte kullanılan, kullanıcı kimliği değiştirilebilen sahte oturum.
///
/// `OturumDenetleyici`'den türetilir (provider'ın beklediği tip budur) ve
/// oturum geri yükleme akışı devre dışı bırakılır: testte ağa gidilmez.
class _SahteOturumDenetleyici extends OturumDenetleyici {
  _SahteOturumDenetleyici()
      : super(kimlikServisi: KimlikServisi(), apiServisi: ApiServisi()) {
    state = const OturumDurumu(isLoading: false);
  }

  @override
  Future<void> oturumuGeriYukle() async {}

  void kullaniciDegistir(int? id) {
    state = OturumDurumu(
      isLoading: false,
      oturumVarMi: id != null,
      profile: id == null ? null : _profil(id),
    );
  }

  static ProfilModel _profil(int id) => ProfilModel(
        id: id,
        username: 'kullanici$id',
        email: 'kullanici$id@ornek.com',
        firstName: 'Kullanıcı',
        lastName: '$id',
        avatarUrl: null,
        bio: '',
        height: 180,
        weight: 75,
        targetWeight: 70,
        startWeight: 80,
        goal: 'Yağ kaybı',
        gender: 'erkek',
        isOnboarded: true,
        birthDate: DateTime(1995, 1, 1),
        joinDate: DateTime(2024, 1, 1),
        customWaterGoalMl: 2500,
        isStaff: false,
        isSuperuser: false,
        postCount: 0,
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Yerel önbellek erişimleri platform eklentisine gitmesin.
    SharedPreferences.setMockInitialValues({});
  });

  test('kullanıcı değişince asistan denetleyicisi yeniden kurulur', () {
    final oturum = _SahteOturumDenetleyici();
    final container = ProviderContainer(
      overrides: [oturumDenetleyiciProvider.overrideWith((ref) => oturum)],
    );
    addTearDown(container.dispose);

    oturum.kullaniciDegistir(1);
    final oncekiAsistan = container.read(asistanProvider);
    expect(oncekiAsistan.messages, isNotEmpty); // karşılama mesajı

    oturum.kullaniciDegistir(2);
    final sonrakiAsistan = container.read(asistanProvider);

    // Yeni kullanıcı için yeni bir denetleyici kurulmalı.
    expect(sonrakiAsistan, isNot(same(oncekiAsistan)));
  });

  test('çıkışta (kullanıcı null) asistan denetleyicisi yeniden kurulur', () {
    final oturum = _SahteOturumDenetleyici();
    final container = ProviderContainer(
      overrides: [oturumDenetleyiciProvider.overrideWith((ref) => oturum)],
    );
    addTearDown(container.dispose);

    oturum.kullaniciDegistir(1);
    final oncekiAsistan = container.read(asistanProvider);

    oturum.kullaniciDegistir(null);
    final sonrakiAsistan = container.read(asistanProvider);

    expect(sonrakiAsistan, isNot(same(oncekiAsistan)));
  });

  test('kullanıcı değişince beslenme denetleyicisi yeniden kurulur', () {
    final oturum = _SahteOturumDenetleyici();
    final container = ProviderContainer(
      overrides: [oturumDenetleyiciProvider.overrideWith((ref) => oturum)],
    );
    addTearDown(container.dispose);

    oturum.kullaniciDegistir(1);
    final oncekiBeslenme = container.read(beslenmeProvider);

    oturum.kullaniciDegistir(2);
    final sonrakiBeslenme = container.read(beslenmeProvider);

    expect(sonrakiBeslenme, isNot(same(oncekiBeslenme)));
  });

  test('kullanıcı değişmedikçe denetleyici yeniden kurulmaz', () async {
    final oturum = _SahteOturumDenetleyici();
    final container = ProviderContainer(
      overrides: [oturumDenetleyiciProvider.overrideWith((ref) => oturum)],
    );
    addTearDown(container.dispose);

    oturum.kullaniciDegistir(1);
    final ilk = container.read(asistanProvider);
    // Aynı kullanıcı, başka bir profil alanı değişti: denetleyici korunur.
    oturum.kullaniciDegistir(1);
    final ikinci = container.read(asistanProvider);

    expect(ikinci, same(ilk));
  });
}
