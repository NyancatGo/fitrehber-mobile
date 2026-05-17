// Makale/içerik verisini temsil eden model.
// API'den gelen JSON bu modele dönüştürülür.

import 'package:html/parser.dart' as html_parser;

const _siteBaseUrl = 'https://fitrehber.com.tr';
const _mediaBaseUrl = '$_siteBaseUrl/media/';
const _mediaPrefixes = ['ckeditor_resimleri/', 'icerik_resimleri/'];

String _asString(Object? value) => value?.toString() ?? '';

String? _normalizeMediaUrl(Object? value) {
  final raw = _asString(value).trim();
  if (raw.isEmpty) return null;

  final uri = Uri.tryParse(raw);
  if (uri != null && uri.hasScheme) return raw;
  if (raw.startsWith('//')) return 'https:$raw';
  if (raw.startsWith('/media/')) return '$_siteBaseUrl$raw';
  if (raw.startsWith('media/')) return '$_siteBaseUrl/$raw';

  return '$_mediaBaseUrl${raw.replaceFirst(RegExp(r'^/+'), '')}';
}

String _normalizeContentUrl(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return value;

  final uri = Uri.tryParse(raw);
  if (uri != null && uri.hasScheme) return raw;
  if (raw.startsWith('//')) return 'https:$raw';

  final withoutSlash = raw.replaceFirst(RegExp(r'^/+'), '');
  final isMediaPath =
      raw.startsWith('/media/') ||
      raw.startsWith('media/') ||
      _mediaPrefixes.any(withoutSlash.startsWith);

  return isMediaPath ? _normalizeMediaUrl(raw)! : raw;
}

String _normalizeArticleHtml(Object? value) {
  final raw = _asString(value);
  if (raw.trim().isEmpty) return '';

  final document = html_parser.parse(raw);
  for (final selector in ['script', 'style', 'head', 'meta', 'link']) {
    document.querySelectorAll(selector).forEach((element) => element.remove());
  }

  final content =
      document.querySelector('article') ??
      document.querySelector('main') ??
      document.body;

  if (content == null) return raw;

  for (final element in content.querySelectorAll('[src]')) {
    final src = element.attributes['src'];
    if (src != null) {
      element.attributes['src'] = _normalizeContentUrl(src);
    }
  }

  for (final element in content.querySelectorAll('[srcset]')) {
    final srcset = element.attributes['srcset'];
    if (srcset != null) {
      element.attributes['srcset'] = srcset
          .split(',')
          .map((candidate) {
            final parts = candidate.trim().split(RegExp(r'\s+'));
            if (parts.isEmpty || parts.first.isEmpty) return candidate;
            parts[0] = _normalizeContentUrl(parts.first);
            return parts.join(' ');
          })
          .join(', ');
    }
  }

  return content.innerHtml;
}

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
  final String _rawYaziTemiz;
  String? _normalizedYaziTemiz;
  final int yorumSayisi;
  final int begeniSayisi;
  final bool begendim;
  final bool kaydedildi;
  final String ozet;
  final int okumaSuresi;

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
    required String yaziTemiz,
    this.yorumSayisi = 0,
    this.begeniSayisi = 0,
    this.begendim = false,
    this.kaydedildi = false,
    this.ozet = '',
    this.okumaSuresi = 0,
  }) : _rawYaziTemiz = yaziTemiz;

  factory IcerikModel.fromJson(Map<String, dynamic> json) {
    final yazi = _asString(json['yazi']);
    final apiYaziTemiz = _asString(json['yazi_temiz']);
    final yaziTemiz = apiYaziTemiz.isNotEmpty ? apiYaziTemiz : yazi;

    return IcerikModel(
      id: json['id'],
      baslik: json['baslik'],
      resim: json['resim'],
      resimUrl: _normalizeMediaUrl(json['resim_url'] ?? json['resim']),
      tur: json['tur'],
      tarih: json['tarih'],
      yazar: Map<String, dynamic>.from(json['yazar'] ?? {}),
      kategori: json['kategori'] != null
          ? Map<String, dynamic>.from(json['kategori'])
          : null,
      yazi: yazi,
      yaziTemiz: yaziTemiz,
      yorumSayisi: json['yorum_sayisi'] is int
          ? json['yorum_sayisi'] as int
          : int.tryParse(json['yorum_sayisi']?.toString() ?? '') ?? 0,
      begeniSayisi: json['begeni_sayisi'] is int
          ? json['begeni_sayisi'] as int
          : int.tryParse(json['begeni_sayisi']?.toString() ?? '') ?? 0,
      begendim: json['begendim'] == true,
      kaydedildi: json['kaydedildi'] == true,
      ozet: _asString(json['ozet']),
      okumaSuresi: json['okuma_suresi'] is int
          ? json['okuma_suresi'] as int
          : int.tryParse(json['okuma_suresi']?.toString() ?? '') ?? 0,
    );
  }

  IcerikModel copyWith({
    int? id,
    String? baslik,
    String? resim,
    String? resimUrl,
    String? tur,
    String? tarih,
    Map<String, dynamic>? yazar,
    Map<String, dynamic>? kategori,
    String? yazi,
    String? yaziTemiz,
    int? yorumSayisi,
    int? begeniSayisi,
    bool? begendim,
    bool? kaydedildi,
    String? ozet,
    int? okumaSuresi,
  }) {
    return IcerikModel(
      id: id ?? this.id,
      baslik: baslik ?? this.baslik,
      resim: resim ?? this.resim,
      resimUrl: resimUrl ?? this.resimUrl,
      tur: tur ?? this.tur,
      tarih: tarih ?? this.tarih,
      yazar: yazar ?? this.yazar,
      kategori: kategori ?? this.kategori,
      yazi: yazi ?? this.yazi,
      yaziTemiz: yaziTemiz ?? _rawYaziTemiz,
      yorumSayisi: yorumSayisi ?? this.yorumSayisi,
      begeniSayisi: begeniSayisi ?? this.begeniSayisi,
      begendim: begendim ?? this.begendim,
      kaydedildi: kaydedildi ?? this.kaydedildi,
      ozet: ozet ?? this.ozet,
      okumaSuresi: okumaSuresi ?? this.okumaSuresi,
    );
  }

  // Kategori adını kolayca almak için yardımcı getter
  String get kategoriAdi => kategori?['isim'] ?? 'Genel';

  String get yaziTemiz =>
      _normalizedYaziTemiz ??= _normalizeArticleHtml(_rawYaziTemiz);

  // Yazar adını kolayca almak için yardımcı getter
  String get yazarAdi => yazar['username'] ?? 'Anonim';

  // Yazarın kullanıcı id'si (profil ekranına geçiş için)
  int? get yazarId {
    final raw = yazar['id'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

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
