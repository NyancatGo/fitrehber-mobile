// ---------------------------------------------------------------------------
// KATEGORİ MODELİ
// ---------------------------------------------------------------------------
// İçeriklerin (makalelerin) gruplandığı kategoriyi temsil eder. Örneğin
// "Beslenme", "Antrenman", "Sağlıklı Yaşam" gibi başlıklar birer kategoridir.
// ---------------------------------------------------------------------------

/// Tek bir içerik kategorisini temsil eden veri modeli.
class KategoriModel {
  /// Kategorinin backend'deki benzersiz kimliği.
  final int id;

  /// Kategorinin ekranda gösterilen adı (örn. "Beslenme").
  final String isim;

  const KategoriModel({required this.id, required this.isim});

  /// API'den gelen JSON nesnesini `KategoriModel`e dönüştürür.
  factory KategoriModel.fromJson(Map<String, dynamic> json) {
    return KategoriModel(id: json['id'], isim: json['isim']);
  }
}
