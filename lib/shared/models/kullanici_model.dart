// ---------------------------------------------------------------------------
// KULLANICI MODELİ
// ---------------------------------------------------------------------------
// Giriş veya kayıt işlemi başarılı olduğunda API'den dönen kullanıcı verisini
// ve oturum token'larını bir arada tutar.
// ---------------------------------------------------------------------------

/// Oturum açmış kullanıcıyı ve kimlik token'larını temsil eden veri modeli.
class KullaniciModel {
  /// Kullanıcının benzersiz kimliği.
  final int id;

  /// Kullanıcı adı.
  final String username;

  /// E-posta adresi.
  final String email;

  /// API isteklerinde kullanılan erişim token'ı (kısa ömürlü — yaklaşık 1 gün).
  final String accessToken;

  /// Erişim token'ının süresi dolunca yenisini almak için kullanılan
  /// yenileme token'ı (uzun ömürlü — yaklaşık 30 gün).
  final String refreshToken;

  KullaniciModel({
    required this.id,
    required this.username,
    required this.email,
    required this.accessToken,
    required this.refreshToken,
  });

  /// API'den gelen JSON verisini `KullaniciModel` nesnesine dönüştürür.
  ///
  /// Token'lar genelde JSON gövdesinin dışında ayrı geldiği için [access] ve
  /// [refresh] parametre olarak alınır. `id` alanı backend tarafından bazen
  /// metin bazen sayı gönderildiğinden güvenli biçimde sayıya çevrilir.
  factory KullaniciModel.fromJson(
    Map<String, dynamic> json,
    String access,
    String refresh,
  ) {
    return KullaniciModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      username: json['username'].toString(),
      email: (json['email'] ?? '').toString(),
      accessToken: access,
      refreshToken: refresh,
    );
  }
}
