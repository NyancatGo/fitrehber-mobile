// API'nin `yazi_mobil_bloklar` çıktısını modelleyen kontrat katmanı.
// Backend HTML'i paragraph/figure/infoBox gibi semantik bloklara ayırır; mobil
// her tipi native widget olarak çizer. Blok yoksa eski HTML geri dönüş yolu çalışır.

enum IcerikBlokTuru {
  paragraf,
  giris,
  baslik,
  gorsel,
  alinti,
  liste,
  tablo,
  ayirici,
  bilgiKutusu,
  metrikIzgarasi,
  kartIzgarasi,
  bolumBasligi,
  bilinmeyen,
}

IcerikBlokTuru _typeFromString(String? raw) {
  switch (raw) {
    case 'paragraph':
      return IcerikBlokTuru.paragraf;
    case 'lead':
      return IcerikBlokTuru.giris;
    case 'heading':
      return IcerikBlokTuru.baslik;
    case 'figure':
      return IcerikBlokTuru.gorsel;
    case 'quote':
      return IcerikBlokTuru.alinti;
    case 'list':
      return IcerikBlokTuru.liste;
    case 'table':
      return IcerikBlokTuru.tablo;
    case 'divider':
      return IcerikBlokTuru.ayirici;
    case 'infoBox':
      return IcerikBlokTuru.bilgiKutusu;
    case 'metricGrid':
      return IcerikBlokTuru.metrikIzgarasi;
    case 'cardGrid':
      return IcerikBlokTuru.kartIzgarasi;
    case 'sectionHead':
      return IcerikBlokTuru.bolumBasligi;
    default:
      return IcerikBlokTuru.bilinmeyen;
  }
}

/// Bilgi kutusu tonu — UI'da renk/ikon seçimi için.
enum BilgiKutusuTonu { bilgi, uyari, basari, kaynak, icindekiler }

BilgiKutusuTonu _toneFromString(String? raw) {
  switch (raw) {
    case 'warning':
      return BilgiKutusuTonu.uyari;
    case 'success':
      return BilgiKutusuTonu.basari;
    case 'source':
      return BilgiKutusuTonu.kaynak;
    case 'toc':
      return BilgiKutusuTonu.icindekiler;
    case 'info':
    default:
      return BilgiKutusuTonu.bilgi;
  }
}

class IcerikBlok {
  final IcerikBlokTuru tur;
  final Map<String, dynamic> raw;

  const IcerikBlok({required this.tur, required this.raw});

  factory IcerikBlok.fromJson(Map<String, dynamic> json) {
    return IcerikBlok(
      tur: _typeFromString(json['type']?.toString()),
      raw: json,
    );
  }

  // -- Tip-spesifik getter'lar: JSON key'leri backend kontratı olduğu için korunur.

  /// paragraph, lead, quote, heading
  String get text => (raw['text'] ?? '').toString();

  /// paragraph, lead, quote — inline HTML (b, strong, em, a, br ...)
  String get html => (raw['html'] ?? '').toString();

  /// heading: 2..4
  int get level {
    final v = raw['level'];
    if (v is int) return v.clamp(2, 4);
    return int.tryParse(v?.toString() ?? '') ?? 2;
  }

  /// figure
  String get src => (raw['src'] ?? '').toString();
  String get alt => (raw['alt'] ?? '').toString();
  String get caption => (raw['caption'] ?? '').toString();

  /// Görsel oranı backend'den gelirse kullanılır; yoksa çizici 16/9'a düşer.
  double? get aspectRatio {
    final v = raw['aspectRatio'];
    if (v is num) {
      final d = v.toDouble();
      if (d > 0 && d.isFinite) return d;
      return null;
    }
    if (v == null) return null;
    final parsed = double.tryParse(v.toString());
    if (parsed != null && parsed > 0 && parsed.isFinite) return parsed;
    return null;
  }

  /// Bölüm başlığı numarası boş olabilir; boşsa rozet çizilmez.
  String get number => (raw['number'] ?? '').toString();

  /// quote
  String get cite => (raw['cite'] ?? '').toString();

  /// list
  bool get ordered => raw['ordered'] == true;
  List<IcerikListeOgesi> get items {
    final list = raw['items'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((m) => IcerikListeOgesi.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// table
  List<List<IcerikTabloHucresi>> get rows {
    final list = raw['rows'];
    if (list is! List) return const [];
    return list
        .whereType<List>()
        .map(
          (row) => row
              .whereType<Map>()
              .map(
                (m) =>
                    IcerikTabloHucresi.fromJson(Map<String, dynamic>.from(m)),
              )
              .toList(),
        )
        .toList();
  }

  /// infoBox
  BilgiKutusuTonu get tone => _toneFromString(raw['tone']?.toString());
  String get title => (raw['title'] ?? '').toString();
  List<IcerikBlok> get children {
    final list = raw['children'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((m) => IcerikBlok.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// Metrik kartları: büyük değer + küçük açıklama.
  List<IcerikMetrikOgesi> get metrics {
    final list = raw['items'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((m) => IcerikMetrikOgesi.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// İçerik kartları: başlık, açıklama paragrafları ve opsiyonel liste.
  List<IcerikKartOgesi> get cards {
    final list = raw['items'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((m) => IcerikKartOgesi.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }
}

class IcerikListeOgesi {
  final String text;
  final String html;

  const IcerikListeOgesi({required this.text, required this.html});

  factory IcerikListeOgesi.fromJson(Map<String, dynamic> json) {
    return IcerikListeOgesi(
      text: (json['text'] ?? '').toString(),
      html: (json['html'] ?? '').toString(),
    );
  }
}

class IcerikTabloHucresi {
  final bool header;
  final String text;
  final String html;

  const IcerikTabloHucresi({
    required this.header,
    required this.text,
    required this.html,
  });

  factory IcerikTabloHucresi.fromJson(Map<String, dynamic> json) {
    return IcerikTabloHucresi(
      header: json['header'] == true,
      text: (json['text'] ?? '').toString(),
      html: (json['html'] ?? '').toString(),
    );
  }
}

/// Tek bir metrik kart öğesi.
/// `value` büyük değer, `label` altında görünen açıklamadır.
class IcerikMetrikOgesi {
  final String value;
  final String label;

  const IcerikMetrikOgesi({required this.value, required this.label});

  factory IcerikMetrikOgesi.fromJson(Map<String, dynamic> json) {
    return IcerikMetrikOgesi(
      value: (json['value'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
    );
  }
}

/// Tek bir içerik kartı öğesi.
/// `body` ve `list` içinde satır içi HTML korunur.
class IcerikKartOgesi {
  final String title;
  final List<IcerikListeOgesi> body;
  final List<IcerikListeOgesi> list;

  const IcerikKartOgesi({
    required this.title,
    required this.body,
    required this.list,
  });

  factory IcerikKartOgesi.fromJson(Map<String, dynamic> json) {
    List<IcerikListeOgesi> parseItems(Object? raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((m) => IcerikListeOgesi.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }

    return IcerikKartOgesi(
      title: (json['title'] ?? '').toString(),
      body: parseItems(json['body']),
      list: parseItems(json['list']),
    );
  }
}
