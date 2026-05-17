// Forum cevabı / makale yorumu modeli.
// API'den düz liste gelir; parent/depth alanlarıyla ağaç kurulur.

class YorumModel {
  final int id;
  final String mesaj;
  final String tarih;
  final int? parent;
  final int depth;
  final Map<String, dynamic> yazar;
  final List<YorumModel> yanitlar;

  // Beğeni durumu toggle sonrası güncellenebildiği için mutable.
  int begeniSayisi;
  bool begendim;

  YorumModel({
    required this.id,
    required this.mesaj,
    required this.tarih,
    required this.parent,
    required this.depth,
    required this.yazar,
    this.begeniSayisi = 0,
    this.begendim = false,
    List<YorumModel>? yanitlar,
  }) : yanitlar = yanitlar ?? [];

  factory YorumModel.fromJson(Map<String, dynamic> json) {
    return YorumModel(
      id: json['id'],
      mesaj: (json['mesaj'] ?? '').toString(),
      tarih: (json['tarih'] ?? '').toString(),
      parent: json['parent'] is int
          ? json['parent'] as int
          : int.tryParse(json['parent']?.toString() ?? ''),
      depth: json['depth'] is int
          ? json['depth'] as int
          : int.tryParse(json['depth']?.toString() ?? '') ?? 0,
      yazar: Map<String, dynamic>.from(json['yazar'] ?? {}),
      begeniSayisi: json['begeni_sayisi'] is int
          ? json['begeni_sayisi'] as int
          : int.tryParse(json['begeni_sayisi']?.toString() ?? '') ?? 0,
      begendim: json['begendim'] == true,
    );
  }

  String get yazarAdi => yazar['username']?.toString() ?? 'Anonim';

  int? get yazarId {
    final raw = yazar['id'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  // Düz listeden parent/child ağacı kurar, kök yorumları döner.
  static List<YorumModel> agacKur(List<YorumModel> duzListe) {
    final haritaById = {for (final y in duzListe) y.id: y};
    final kokler = <YorumModel>[];

    for (final yorum in duzListe) {
      final ebeveyn = yorum.parent != null ? haritaById[yorum.parent] : null;
      if (ebeveyn != null) {
        ebeveyn.yanitlar.add(yorum);
      } else {
        kokler.add(yorum);
      }
    }
    return kokler;
  }

  // Bu yorum ve tüm alt yanıtlarının toplam sayısı.
  int get toplamSayi {
    var toplam = 1;
    for (final yanit in yanitlar) {
      toplam += yanit.toplamSayi;
    }
    return toplam;
  }

  // ISO tarihi "2 saat önce" benzeri göreli metne çevirir.
  String get tarihGoreli {
    try {
      final dt = DateTime.parse(tarih).toLocal();
      final fark = DateTime.now().difference(dt);
      if (fark.inSeconds < 60) return 'Az önce';
      if (fark.inMinutes < 60) return '${fark.inMinutes} dk önce';
      if (fark.inHours < 24) return '${fark.inHours} sa önce';
      if (fark.inDays < 30) return '${fark.inDays} gün önce';
      if (fark.inDays < 365) return '${(fark.inDays / 30).floor()} ay önce';
      return '${(fark.inDays / 365).floor()} yıl önce';
    } catch (_) {
      return tarih;
    }
  }
}

/// Profil "Beğenilenler" sekmesi için yorum + ait olduğu içerik özeti.
class YorumOzetModel {
  final int id;
  final String mesaj;
  final String tarih;
  final int? icerikId;
  final String icerikBaslik;
  final Map<String, dynamic> yazar;

  const YorumOzetModel({
    required this.id,
    required this.mesaj,
    required this.tarih,
    required this.icerikId,
    required this.icerikBaslik,
    required this.yazar,
  });

  factory YorumOzetModel.fromJson(Map<String, dynamic> json) {
    return YorumOzetModel(
      id: json['id'],
      mesaj: (json['mesaj'] ?? '').toString(),
      tarih: (json['tarih'] ?? '').toString(),
      icerikId: json['icerik'] is int
          ? json['icerik'] as int
          : int.tryParse(json['icerik']?.toString() ?? ''),
      icerikBaslik: (json['icerik_baslik'] ?? '').toString(),
      yazar: Map<String, dynamic>.from(json['yazar'] ?? {}),
    );
  }

  String get yazarAdi => yazar['username']?.toString() ?? 'Anonim';
}
