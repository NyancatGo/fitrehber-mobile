// Makale/içerik verisini temsil eden model.
// API'den gelen JSON bu modele dönüştürülür.

class IcerikModel {
  final int id;
  final String baslik;
  final String? resim;
  final String? resimUrl;
  final String tur;
  final String tarih;
  final Map<String, dynamic> yazar;
  final Map<String, dynamic>? kategori;
  final String yazi;
  final String yaziTemiz;

  IcerikModel({
    required this.id,
    required this.baslik,
    this.resim,
    this.resimUrl,
    required this.tur,
    required this.tarih,
    required this.yazar,
    this.kategori,
    required this.yazi,
    required this.yaziTemiz,
  });

  factory IcerikModel.fromJson(Map<String, dynamic> json) {
    final yazi = json['yazi'] ?? '';
    return IcerikModel(
      id: json['id'],
      baslik: json['baslik'],
      resim: json['resim'],
      resimUrl: json['resim_url'],
      tur: json['tur'],
      tarih: json['tarih'],
      yazar: Map<String, dynamic>.from(json['yazar'] ?? {}),
      kategori: json['kategori'] != null
          ? Map<String, dynamic>.from(json['kategori'])
          : null,
      yazi: yazi,
      yaziTemiz: json['yazi_temiz'] ?? yazi,
    );
  }

  // Kategori adını kolayca almak için yardımcı getter
  String get kategoriAdi => kategori?['isim'] ?? 'Genel';

  // Yazar adını kolayca almak için yardımcı getter
  String get yazarAdi => yazar['username'] ?? 'Anonim';

  // Tarihi okunabilir formata çevirir (2026-03-15 → 15 Mar 2026)
  String get tarihFormatli {
    try {
      final dt = DateTime.parse(tarih);
      const aylar = [
        'Oca',
        'Şub',
        'Mar',
        'Nis',
        'May',
        'Haz',
        'Tem',
        'Ağu',
        'Eyl',
        'Eki',
        'Kas',
        'Ara',
      ];
      return '${dt.day} ${aylar[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return tarih;
    }
  }
}
