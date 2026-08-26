// Ham hata nesnelerini kullanıcıya gösterilebilecek Türkçe metne çevirir.
// API katmanı zaten anlamlı Türkçe string'ler fırlatır; burada esas amaç
// Dio'nun ham bağlantı/timeout hatalarının arayüze sızmasını engellemektir.

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import 'google_oauth_akisi.dart';

/// Yakalanan bir hatayı kullanıcı dostu, Türkçe bir mesaja dönüştürür.
String kullaniciDostuHata(Object hata) {
  if (hata is GoogleOAuthHatasi) {
    return hata.message;
  }

  if (hata is PlatformException) {
    switch (hata.code) {
      case 'CANCELED':
        return 'Google giriş işlemi iptal edildi.';
      case 'NO_BROWSER':
        return 'Google girişi için uygun bir tarayıcı bulunamadı.';
      case 'FAILED':
        return 'Google giriş işlemi tamamlanamadı. Lütfen tekrar dene.';
    }

    final message = hata.message?.trim();
    if (message != null && message.isNotEmpty) return message;
  }

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
      // DioExceptionType.unknown ve dio'nun ileride ekleyeceği tipler.
      //
      // Açık uç (default) bilerek duruyor: bu enum bize ait değil, dio her
      // minor sürümde yeni değer ekleyebiliyor. Nitekim ekledi de — dio 5.11
      // `transformTimeout` getirdi, buradaki switch exhaustive olmaktan çıktı
      // ve temiz bir checkout'ta uygulama DERLENMEZ hâle geldi. Sürüm
      // `^5.4.3` olduğu için pub bu sürümü çekmekte serbest.
      default:
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
