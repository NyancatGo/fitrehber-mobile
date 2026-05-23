// ---------------------------------------------------------------------------
// SAYFALI (PAGINATED) API YANITI MODELİ
// ---------------------------------------------------------------------------
// Backend, uzun listeleri (içerikler, yorumlar, kullanıcılar...) tek seferde
// göndermez; "sayfa sayfa" gönderir. Bu model işte o sayfa yanıtını temsil eder:
// o sayfadaki kayıtlar + toplam adet + bir sonraki/önceki sayfanın adresi.
//
// Generic (`<T>`) yapı sayesinde her tür liste için yeniden kullanılır:
// `SayfaliYanit<IcerikModel>`, `SayfaliYanit<YorumModel>` gibi.
// ---------------------------------------------------------------------------

/// Backend'in sayfalı liste yanıtını temsil eden genel amaçlı model.
class SayfaliYanit<T> {
  /// Bu sayfada dönen kayıtlar.
  final List<T> sonuclar;

  /// Tüm sayfalardaki toplam kayıt sayısı.
  final int toplam;

  /// Bir sonraki sayfanın adresi; son sayfadaysak `null`.
  final String? sonraki;

  /// Bir önceki sayfanın adresi; ilk sayfadaysak `null`.
  final String? onceki;

  const SayfaliYanit({
    required this.sonuclar,
    required this.toplam,
    this.sonraki,
    this.onceki,
  });

  /// Yüklenecek bir sonraki sayfa var mı?
  bool get sonrakiVarMi => sonraki != null;

  /// API yanıtını `SayfaliYanit`e dönüştürür.
  ///
  /// [data] iki farklı biçimde gelebilir; ikisi de desteklenir:
  /// * Düz bir liste (`[...]`) — sayfalama yoksa.
  /// * `{count, next, previous, results}` haritası — standart sayfalı yanıt.
  ///
  /// [fromJson], tek bir kaydı `T` tipine çeviren dönüştürücü fonksiyondur.
  factory SayfaliYanit.fromJson(
    dynamic data,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    // Durum 1: Yanıt doğrudan bir liste ise — sayfalama bilgisi yoktur.
    if (data is List) {
      final sonuclar = data
          .map((item) => fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
      return SayfaliYanit<T>(sonuclar: sonuclar, toplam: sonuclar.length);
    }

    // Durum 2: Yanıt standart sayfalı harita ise.
    if (data is Map) {
      final rawResults = data['results'];
      final sonuclar = rawResults is List
          ? rawResults
                .map((item) => fromJson(Map<String, dynamic>.from(item as Map)))
                .toList()
          : <T>[];

      return SayfaliYanit<T>(
        sonuclar: sonuclar,
        toplam: _asInt(data['count']) ?? sonuclar.length,
        sonraki: _asNullableString(data['next']),
        onceki: _asNullableString(data['previous']),
      );
    }

    // Beklenmeyen biçim: boş bir yanıt döndür (uygulama çökmesin).
    return SayfaliYanit<T>(sonuclar: const [], toplam: 0);
  }
}

/// Gelen değeri güvenli biçimde tam sayıya çevirir; çevrilemezse `null` döner.
int? _asInt(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}

/// Gelen değeri metne çevirir; boş veya `null` ise `null` döner.
String? _asNullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
