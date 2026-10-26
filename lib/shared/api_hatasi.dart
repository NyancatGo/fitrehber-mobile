// ---------------------------------------------------------------------------
// API HATASI (TİPLİ İSTİSNA SÖZLEŞMESİ)
// ---------------------------------------------------------------------------
// `ApiServisi` sunucudan başarısız bir HTTP yanıtı aldığında düz `String`
// yerine bu sınıfı fırlatır. Böylece üst katmanlar hatayı metin eşleştirmesi
// yapmadan, HTTP durum koduna göre güvenle sınıflandırabilir:
//
//   * Geçici (transient) hatalar  -> 401, 408, 425, 429, 5xx
//     İşlem daha sonra aynen tekrar denendiğinde başarılı olabilir. Çevrimdışı
//     kuyruk (outbox) bu durumda işlemi ASLA düşürmez.
//   * Kalıcı (permanent) hatalar  -> Diğer 4xx (400, 403, 404, 409, 422 ...)
//     Aynı istek kaç kez tekrarlanırsa tekrarlansın sunucu reddeder.
//
// `toString()` kullanıcıya gösterilecek Türkçe mesajı döndürür; bu sayede
// `e.toString()` / `'$e'` kullanan mevcut arayüz kodu değişmeden çalışır.
// ---------------------------------------------------------------------------

/// Backend'in başarısız bir HTTP yanıtını temsil eden tipli istisna.
class ApiHatasi implements Exception {
  /// Kullanıcıya gösterilebilecek Türkçe hata mesajı.
  final String mesaj;

  /// Sunucunun döndürdüğü HTTP durum kodu (bilinmiyorsa `null`).
  final int? statusCode;

  const ApiHatasi(this.mesaj, {this.statusCode});

  /// Oturum yok / süresi dolmuş (401).
  bool get yetkiHatasiMi => statusCode == 401;

  /// Aynı işlem ileride tekrar denendiğinde başarılı olabilir mi?
  ///
  /// 401: token yenilenince / kullanıcı tekrar giriş yapınca düzelir.
  /// 408/425/429: zaman aşımı, erken istek veya hız sınırı (throttle).
  /// 5xx: sunucu tarafı geçici arıza / bakım / ağ geçidi hatası.
  bool get geciciMi {
    final kod = statusCode;
    if (kod == null) return false;
    return kod == 401 || kod == 408 || kod == 425 || kod == 429 || kod >= 500;
  }

  /// İstek, içeriği nedeniyle sunucu tarafından kalıcı olarak reddedildi mi?
  ///
  /// Yalnızca geçici sayılmayan 4xx kodları kalıcıdır. Durum kodu bilinmiyorsa
  /// güvenli tarafta kalınır ve hata kalıcı SAYILMAZ (veri düşürülmez).
  bool get kaliciMi {
    final kod = statusCode;
    if (kod == null) return false;
    return kod >= 400 && kod < 500 && !geciciMi;
  }

  @override
  String toString() => mesaj;
}
