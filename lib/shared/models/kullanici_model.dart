// Giriş/kayıt sonrası API'den dönen kullanıcı verisini temsil eder.
// accessToken: API isteklerinde kullanılır (1 gün geçerli).
// refreshToken: accessToken süresi dolunca yeni token almak için kullanılır (30 gün geçerli).

class KullaniciModel {
  final int    id;
  final String username;
  final String email;
  final String accessToken;
  final String refreshToken;

  KullaniciModel({
    required this.id,
    required this.username,
    required this.email,
    required this.accessToken,
    required this.refreshToken,
  });

  // API'den gelen JSON verisini KullaniciModel nesnesine dönüştürür.
  // id bazen int bazen String gelebileceği için güvenli parse edilir.
  factory KullaniciModel.fromJson(
    Map<String, dynamic> json,
    String access,
    String refresh,
  ) {
    return KullaniciModel(
      id:           json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      username:     json['username'].toString(),
      email:        (json['email'] ?? '').toString(),
      accessToken:  access,
      refreshToken: refresh,
    );
  }
}
