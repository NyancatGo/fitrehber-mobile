class ApiConstants {
  static const String baseUrl = 'https://api.fitrehber.com.tr/api';
  static const String webUrl = 'https://fitrehber.com.tr';

  /// API sayfalama varsayılan sayfa boyutu (OptionalPageNumberPagination).
  static const int pageSize = 20;

  static const String kategoriler = '$baseUrl/kategoriler/';
  static const String icerikler = '$baseUrl/icerikler/';
  static const String profil = '$baseUrl/profil/';
  static const String profilOnboard = '$baseUrl/profil/onboard/';
  static const String beslenmeSu = '$baseUrl/profil/beslenme-su/';
  static const String besinler = '$baseUrl/besinler/';
  static const String beslenmeEkle = '$baseUrl/beslenme/ekle/';

  static const String login = '$baseUrl/auth/login/';
  static const String register = '$baseUrl/auth/register/';
  static const String googleToken = '$baseUrl/auth/google/token/';

  static const String aiChat = '$baseUrl/ai/chat/';

  static String profilDetay(int userId) => '$profil$userId/';
  static String profilIcerikleri(int userId) => '$profil$userId/icerikler/';
  static String profilKaydedilenler(int userId) =>
      '$profil$userId/kaydedilenler/';
  static String profilBegeniler(int userId) => '$profil$userId/begeniler/';

  static String yorumlar(int icerikId) => '$icerikler$icerikId/yorumlar/';
  static String yorumYanitlari(int yorumId) =>
      '$baseUrl/yorumlar/$yorumId/yanitlar/';
  static String yorumDetay(int yorumId) => '$baseUrl/yorumlar/$yorumId/';
  static String yorumBegen(int yorumId) => '$baseUrl/yorumlar/$yorumId/begen/';
  static String icerikBegen(int icerikId) => '$icerikler$icerikId/begen/';
  static String icerikKaydet(int icerikId) => '$icerikler$icerikId/kaydet/';
  static String beslenmeSil(int ogunId) => '$baseUrl/beslenme/sil/$ogunId/';
  static String beslenmeGuncelle(int ogunId) =>
      '$baseUrl/beslenme/guncelle/$ogunId/';
}
