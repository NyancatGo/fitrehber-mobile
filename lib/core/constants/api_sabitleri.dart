// ---------------------------------------------------------------------------
// API SABİTLERİ
// ---------------------------------------------------------------------------
// Bu dosya, uygulamanın konuştuğu backend (sunucu) adreslerini tek bir yerde
// toplar. Adresler kod içine dağıtılmaz; böylece sunucu adresi değişirse
// sadece burası güncellenir ve tüm uygulama otomatik olarak yeni adresi kullanır.
// ---------------------------------------------------------------------------

/// Backend API uç noktalarının merkezi tanımı.
///
/// Sınıf örneği oluşturulmaz; tüm üyeler `static`tir ve doğrudan
/// `ApiSabitleri.girisYap` gibi çağrılır.
class ApiSabitleri {
  /// Mobil uygulamanın veri alışverişi yaptığı ana API kök adresi.
  static const String baseUrl = 'https://api.fitrehber.com.tr/api';

  /// Web sitesinin kök adresi. Bazı kimlik doğrulama işlemleri web tarafında
  /// JSON uç noktaları üzerinden yürütüldüğü için ayrıca tutulur.
  static const String webUrl = 'https://fitrehber.com.tr';

  /// Sayfalı (paginated) listelerde her istekte kaç kayıt çekileceği.
  /// Backend tarafındaki `OptionalPageNumberPagination` ile uyumludur.
  static const int pageSize = 20;

  // --- İçerik ve kategori uç noktaları -------------------------------------

  /// İçerik kategorilerinin listesi.
  static const String kategoriler = '$baseUrl/kategoriler/';

  /// Makale/içerik listesi.
  static const String icerikler = '$baseUrl/icerikler/';

  // --- Profil uç noktaları --------------------------------------------------

  /// Oturum açan kullanıcının kendi profili.
  static const String profil = '$baseUrl/profil/';

  /// Onboarding (ilk kurulum) adımında profil bilgilerini kaydetme.
  static const String profilOnboard = '$baseUrl/profil/onboard/';

  /// Günlük beslenme ve su takibi verileri.
  static const String beslenmeSu = '$baseUrl/profil/beslenme-su/';

  // --- Beslenme uç noktaları ------------------------------------------------

  /// Besin (yiyecek) veritabanında arama.
  static const String besinler = '$baseUrl/besinler/';

  /// Mobil offline aramada zayıf/boş sonuç sinyali.
  static const String besinlerAramaLog = '$baseUrl/besinler/arama-log/';

  /// Kullanıcı besin önerilerini moderasyon kuyruğuna gönderme.
  static const String besinlerKatki = '$baseUrl/besinler/katki/';

  /// Barkod sorgulama: önce DB, yoksa sunucu tarafı OpenFoodFacts staging.
  static const String besinlerBarkodSorgula =
      '$baseUrl/besinler/barkod-sorgula/';

  /// Yerel besin veritabanını sunucuyla senkronlama (offline arama için tek
  /// kaynak). `?since=` ile yalnız değişenler (delta), `offset`/`limit` ile
  /// sayfalı çekilir.
  static const String besinlerSync = '$baseUrl/besinler/sync/';

  /// Bir öğüne yeni besin kaydı ekleme.
  static const String beslenmeEkle = '$baseUrl/beslenme/ekle/';

  /// Bir önceki günün öğünlerini seçili (boş) güne kopyalama.
  static const String beslenmeKopyala = '$baseUrl/beslenme/kopyala/';

  /// Son kullanılan besinler (hızlı yeniden ekleme için).
  static const String sonBesinler = '$baseUrl/beslenme/son-besinler/';

  // --- Kimlik doğrulama uç noktaları ---------------------------------------

  /// E-posta + parola ile giriş; karşılığında JWT token döner.
  static const String girisYap = '$baseUrl/auth/login/';

  /// Google ile giriş sırasında alınan Google token'ının doğrulanması.
  static const String googleToken = '$baseUrl/auth/google/token/';

  /// Yeni kullanıcı kaydı (web tarafındaki JSON uç noktası).
  static const String kayitOl = '$webUrl/mobile/auth/register/';

  /// E-posta doğrulama bağlantısını yeniden gönderme.
  static const String dogrulamaMailiTekrarGonder =
      '$webUrl/mobile/auth/verification/resend/';

  /// Parola sıfırlama bağlantısı talebi.
  static const String sifreSifirlamaIste =
      '$webUrl/mobile/auth/password-reset/request/';

  /// Süresi dolan erişim token'ını yenileme (refresh token ile).
  static const String tokenRefresh = '$baseUrl/auth/token/refresh/';

  // --- Yapay zekâ asistanı --------------------------------------------------

  /// AI asistanına mesaj gönderme uç noktası.
  static const String aiChat = '$baseUrl/ai/chat/';

  // --- Parametreli (dinamik) uç noktalar -----------------------------------
  // Aşağıdaki fonksiyonlar, içine kimlik (id) alıp tam adresi üreten yardımcılardır.

  /// Belirli bir kullanıcının profil detayını döndüren adres.
  static String profilDetay(int userId) => '$profil$userId/';

  /// Belirli bir kullanıcının paylaştığı içerikler.
  static String profilIcerikleri(int userId) => '$profil$userId/icerikler/';

  /// Belirli bir kullanıcının kaydettiği içerikler.
  static String profilKaydedilenler(int userId) =>
      '$profil$userId/kaydedilenler/';

  /// Belirli bir kullanıcının beğendiği içerikler.
  static String profilBegeniler(int userId) => '$profil$userId/begeniler/';

  /// Bir içeriğe ait yorumların listesi.
  static String yorumlar(int icerikId) => '$icerikler$icerikId/yorumlar/';

  /// Bir yoruma yapılan yanıtların listesi.
  static String yorumYanitlari(int yorumId) =>
      '$baseUrl/yorumlar/$yorumId/yanitlar/';

  /// Tek bir yorumun detayı (güncelleme/silme için de kullanılır).
  static String yorumDetay(int yorumId) => '$baseUrl/yorumlar/$yorumId/';

  /// Bir yorumu beğenme / beğeniyi geri alma.
  static String yorumBegen(int yorumId) => '$baseUrl/yorumlar/$yorumId/begen/';

  /// Bir içeriği beğenme / beğeniyi geri alma.
  static String icerikBegen(int icerikId) => '$icerikler$icerikId/begen/';

  /// Bir içeriği kaydetme / kaydı geri alma.
  static String icerikKaydet(int icerikId) => '$icerikler$icerikId/kaydet/';

  /// Bir beslenme (öğün) kaydını silme.
  static String beslenmeSil(int ogunId) => '$baseUrl/beslenme/sil/$ogunId/';

  /// Bir beslenme (öğün) kaydını güncelleme.
  static String beslenmeGuncelle(int ogunId) =>
      '$baseUrl/beslenme/guncelle/$ogunId/';
}
