// Tüm API endpoint adresleri bu dosyada toplandı.
// Bir adres değişirse sadece buradan güncellenir.

class ApiConstants {
  // Temel API adresi
  static const String baseUrl = 'https://api.fitrehber.com.tr/api';

  // İçerik endpoint'leri
  static const String kategoriler = '$baseUrl/kategoriler/';
  static const String icerikler   = '$baseUrl/icerikler/';
  static const String profil      = '$baseUrl/profil/';

  // Kimlik doğrulama endpoint'leri
  static const String login    = '$baseUrl/auth/login/';
  static const String register = '$baseUrl/auth/register/';
}
