// Ham hata nesnelerini kullanıcıya gösterilebilecek Türkçe metne çevirir.
// API katmanı zaten anlamlı Türkçe string'ler fırlatır; burada esas amaç
// Dio'nun ham bağlantı/timeout hatalarının arayüze sızmasını engellemektir.

import 'package:dio/dio.dart';

/// Yakalanan bir hatayı kullanıcı dostu, Türkçe bir mesaja dönüştürür.
String kullaniciDostuHata(Object hata) {
  if (hata is DioException) {
    switch (hata.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Bağlantı zaman aşımına uğradı. İnternet bağlantını kontrol et.';
      case DioExceptionType.connectionError:
        return 'İnternete bağlanılamadı. Bağlantını kontrol et.';
      case DioExceptionType.badCertificate:
        return 'Güvenli bağlantı kurulamadı. Lütfen daha sonra tekrar dene.';
      case DioExceptionType.cancel:
        return 'İstek iptal edildi.';
      case DioExceptionType.badResponse:
        return 'Sunucu beklenmeyen bir yanıt döndü. Lütfen tekrar dene.';
      case DioExceptionType.unknown:
        return 'Beklenmeyen bir hata oluştu. Lütfen tekrar dene.';
    }
  }

  // API katmanından gelen düz string hatalar zaten Türkçe ve anlaşılırdır.
  if (hata is String) return hata;

  final metin = hata.toString();
  // "Exception: ..." gibi teknik önekleri ayıkla.
  final temiz = metin.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  if (temiz.isEmpty) return 'Beklenmeyen bir hata oluştu. Lütfen tekrar dene.';
  return temiz;
}
