// ---------------------------------------------------------------------------
// OTURUM KONTROLCÜSÜ
// ---------------------------------------------------------------------------
// Uygulamanın oturum karar noktasıdır: token var mı, profil yüklendi mi,
// ilk kurulum tamamlandı mı? Router bu state'e bakarak kullanıcıyı doğru
// ekrana yönlendirir. Ağ kesintisinde token'ı silme kararı burada verilmez.
// ---------------------------------------------------------------------------

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_servisi.dart';
import 'kimlik_servisi.dart';
import 'google_oauth_akisi.dart';
import 'models/profil_model.dart';
import 'services/besin_senkron_servisi.dart';

/// Kimlik doğrulama servisini sağlayan provider.
final kimlikServisiProvider = Provider<KimlikServisi>((ref) => KimlikServisi());

/// API servisini sağlayan provider.
final apiServisiProvider = Provider<ApiServisi>((ref) => ApiServisi());

/// Uygulamanın oturum durumunu tutan ve yöneten ana provider.
///
/// Oluşturulur oluşturulmaz `oturumuGeriYukle()` çağrılır; önceki oturum
/// varsa uygulama açılışında sessizce geri yüklenir.
final oturumDenetleyiciProvider =
    StateNotifierProvider<OturumDenetleyici, OturumDurumu>((ref) {
      final denetleyici = OturumDenetleyici(
        kimlikServisi: ref.watch(kimlikServisiProvider),
        apiServisi: ref.watch(apiServisiProvider),
      );
      denetleyici.oturumuGeriYukle();
      return denetleyici;
    });

/// Oturumun anlık durumunu temsil eden değişmez (immutable) veri sınıfı.
class OturumDurumu {
  /// Oturum bilgisi hâlâ okunuyor/yükleniyor mu?
  final bool isLoading;

  /// Kullanıcı giriş yapmış durumda mı?
  final bool oturumVarMi;

  /// Giriş yapan kullanıcının profili (yüklenmediyse `null`).
  final ProfilModel? profile;

  /// Son işlemde oluşan hata mesajı (yoksa `null`).
  final String? error;

  const OturumDurumu({
    this.isLoading = true,
    this.oturumVarMi = false,
    this.profile,
    this.error,
  });

  /// Kullanıcı ilk kurulum adımını tamamlamış mı?
  bool get isOnboarded => profile?.isOnboarded ?? false;

  OturumDurumu copyWith({
    bool? isLoading,
    bool? oturumVarMi,
    ProfilModel? profile,
    bool clearProfile = false,
    String? error,
    bool clearError = false,
  }) {
    return OturumDurumu(
      isLoading: isLoading ?? this.isLoading,
      oturumVarMi: oturumVarMi ?? this.oturumVarMi,
      profile: clearProfile ? null : (profile ?? this.profile),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Oturum durumunu değiştiren tüm işlemleri (giriş, kayıt, çıkış, profil
/// yenileme) yürüten kontrolcü.
class OturumDenetleyici extends StateNotifier<OturumDurumu> {
  final KimlikServisi _kimlikServisi;
  final ApiServisi _apiServisi;

  OturumDenetleyici({
    required KimlikServisi kimlikServisi,
    required ApiServisi apiServisi,
  }) : _kimlikServisi = kimlikServisi,
       _apiServisi = apiServisi,
       super(const OturumDurumu());

  /// Uygulama açılışında önceki oturumu geri yüklemeye çalışır.
  ///
  /// Kayıtlı token varsa profil yüklenir; yoksa kullanıcı giriş ekranına düşer.
  Future<void> oturumuGeriYukle() async {
    // Web OAuth dönüşünde uygulama yeniden açılır; URL'deki code/state burada
    // tüketilmezse normal token okuma akışı yanlışlıkla giriş ekranına düşebilir.
    if (kIsWeb && await _webGoogleDonusunuTuketmeyiDene()) {
      return;
    }

    final token = await _kimlikServisi.accessTokenOku();
    if (token == null || token.isEmpty) {
      state = const OturumDurumu(isLoading: false);
      return;
    }

    await _profiliYukle();
  }

  /// Web akışında Google OAuth dönüşünü işler.
  ///
  /// URL'de `code`+`state` ve depoda bekleyen PKCE isteği varsa token exchange
  /// yapılır. İşlenecek dönüş yoksa normal token tabanlı geri yükleme sürer.
  Future<bool> _webGoogleDonusunuTuketmeyiDene() async {
    final donus = GoogleOAuthAkisi.webDonusunuCoz(Uri.base);
    if (donus == null) return false;

    final bekleyenIstek = await _kimlikServisi.bekleyenGoogleIstekOku();
    if (bekleyenIstek == null) {
      // Bekleyen istek yoksa kod zaten tüketilmiş veya sayfa elle yenilenmiştir.
      return false;
    }

    // Tek kullanımlık: aynı Google kodu sayfa yenilenince tekrar denenmesin.
    await _kimlikServisi.bekleyenGoogleIstekTemizle();

    // CSRF koruması: dönen state, başlatılan state ile birebir eşleşmeli.
    if (bekleyenIstek.state != donus.state) {
      return false;
    }

    try {
      await _kimlikServisi.googleKoduIleOturumAc(
        code: donus.code,
        state: donus.state,
        codeVerifier: bekleyenIstek.codeVerifier,
      );
      await _profiliYukle(hatadaCikisYap: false);
    } catch (error) {
      state = OturumDurumu(isLoading: false, error: error.toString());
    }
    return true;
  }

  /// Kullanıcı adı ve parola ile giriş yapar, ardından profili yükler.
  Future<void> girisYap(String username, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _kimlikServisi.girisYap(username, password);
      await _profiliYukle(hatadaCikisYap: false);
    } catch (error) {
      state = OturumDurumu(isLoading: false, error: error.toString());
      rethrow;
    }
  }

  /// Yeni kullanıcı kaydı oluşturur.
  ///
  /// Kayıt sonrası e-posta doğrulaması gerektiği için oturum otomatik açılmaz;
  /// kullanıcı doğrulama yaptıktan sonra giriş yapar.
  Future<void> kayitOl(
    String username,
    String password,
    String email,
    String password2,
  ) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _kimlikServisi.kayitOl(username, password, email, password2);
      await _kimlikServisi.cikisYap();
      state = const OturumDurumu(isLoading: false);
    } catch (error) {
      state = OturumDurumu(isLoading: false, error: error.toString());
      rethrow;
    }
  }

  /// Google'dan alınan kodla giriş yapar (mobil OAuth akışı).
  Future<void> googleKoduIleGirisYap({
    required String code,
    required String stateToken,
    required String codeVerifier,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _kimlikServisi.googleKoduIleOturumAc(
        code: code,
        state: stateToken,
        codeVerifier: codeVerifier,
      );
      await _profiliYukle(hatadaCikisYap: false);
    } catch (error) {
      state = OturumDurumu(isLoading: false, error: error.toString());
      rethrow;
    }
  }

  /// İlk kurulum bilgilerini kaydeder ve oturumu ana uygulamaya hazır hale getirir.
  Future<void> ilkKurulumuTamamla(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final profile = await _apiServisi.ilkKurulumuTamamla(data);
      state = OturumDurumu(
        isLoading: false,
        oturumVarMi: true,
        profile: profile,
      );
      _besinSenkronunuTetikle();
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
      rethrow;
    }
  }

  /// Besin veritabanını arka planda indirmeye başlatır (fire-and-forget).
  ///
  /// Oturum kurulur kurulmaz çağrılır — beslenme ekranı açılmasını beklemeyiz.
  /// Bundled JSON seed kaldırıldığı için besin araması bu senkrona bağımlı;
  /// erken tetikleyerek kullanıcının "veritabanı hazırlanıyor" ekranını görme
  /// ihtimalini en aza indiriyoruz. `senkronEt` kendi 6 saatlik throttle'ına
  /// sahip olduğu için her oturumda ağ trafiği oluşturmaz ve hata fırlatmaz.
  void _besinSenkronunuTetikle() {
    unawaited(BesinSenkronServisi.instance.senkronEt());
  }

  /// Oturumu kapatır ve durumu sıfırlar.
  Future<void> cikisYap() async {
    await _kimlikServisi.cikisYap();
    state = const OturumDurumu(isLoading: false);
  }

  /// Profili sunucudan yeniden çeker (ör. profil düzenlendikten sonra).
  Future<void> profiliYenile() => _profiliYukle(hatadaCikisYap: false);

  /// Profil yükleme hatasında çıkış yapıp yapmama kararını merkezileştirir.
  ///
  /// `hatadaCikisYap=false`, giriş/OAuth sonrası profil çağrısı düşse bile
  /// token'ı korur; gerçek auth hatasında çıkış kararı çağıran akışa bırakılır.
  Future<void> _profiliYukle({bool hatadaCikisYap = true}) async {
    try {
      final profile = await _apiServisi.profiliGetir();
      state = OturumDurumu(
        isLoading: false,
        oturumVarMi: true,
        profile: profile,
      );
      _besinSenkronunuTetikle();
    } catch (error) {
      // ApiServisi 401/403'ü DioException olarak değil, okunabilir hata olarak
      // döndürür. DioException daha çok ağ kesintisidir; çevrimdışıyken
      // kullanıcıyı zorla çıkarmamak için oturumu ve varsa önbellek profili koruruz.
      final isNetworkError = error is DioException;
      if (isNetworkError || !hatadaCikisYap) {
        state = OturumDurumu(
          isLoading: false,
          oturumVarMi: true,
          profile: state.profile ?? ProfilModel.empty(),
          error: error.toString(),
        );
        return;
      }
      await _kimlikServisi.cikisYap();
      state = OturumDurumu(isLoading: false, error: error.toString());
    }
  }
}
