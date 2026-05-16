class ApiConstants {
  static const String baseUrl = 'https://api.fitrehber.com.tr/api';

  static const String kategoriler = '$baseUrl/kategoriler/';
  static const String icerikler = '$baseUrl/icerikler/';
  static const String profil = '$baseUrl/profil/';

  static const String login = '$baseUrl/auth/login/';
  static const String register = '$baseUrl/auth/register/';

  static const String aiChat = '$baseUrl/ai/chat/';

  static String profilDetay(int userId) => '$profil$userId/';
}
