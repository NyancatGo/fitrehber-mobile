// Mobil makale render bloku — API'nin `yazi_mobil_bloklar` cıktısının modeli.
//
// Backend `_normalize_article_blocks` her HTML node'unu su semantik bloklara
// cevirir: paragraph, lead, heading, figure, quote, list, table, divider,
// infoBox, metricGrid, cardGrid. Mobil tarafta her blok tipini ayri bir Flutter
// widget'i render eder.
//
// Backward compat: API bos liste veya null donerse mobil eski HTML renderer'a
// duser (IcerikModel.yaziTemiz).

enum ArticleBlockType {
  paragraph,
  lead,
  heading,
  figure,
  quote,
  list,
  table,
  divider,
  infoBox,
  metricGrid,
  cardGrid,
  unknown,
}

ArticleBlockType _typeFromString(String? raw) {
  switch (raw) {
    case 'paragraph':
      return ArticleBlockType.paragraph;
    case 'lead':
      return ArticleBlockType.lead;
    case 'heading':
      return ArticleBlockType.heading;
    case 'figure':
      return ArticleBlockType.figure;
    case 'quote':
      return ArticleBlockType.quote;
    case 'list':
      return ArticleBlockType.list;
    case 'table':
      return ArticleBlockType.table;
    case 'divider':
      return ArticleBlockType.divider;
    case 'infoBox':
      return ArticleBlockType.infoBox;
    case 'metricGrid':
      return ArticleBlockType.metricGrid;
    case 'cardGrid':
      return ArticleBlockType.cardGrid;
    default:
      return ArticleBlockType.unknown;
  }
}

/// InfoBox tonu — UI'da renk/ikon seçimi için.
enum InfoBoxTone { info, warning, success, source, toc }

InfoBoxTone _toneFromString(String? raw) {
  switch (raw) {
    case 'warning':
      return InfoBoxTone.warning;
    case 'success':
      return InfoBoxTone.success;
    case 'source':
      return InfoBoxTone.source;
    case 'toc':
      return InfoBoxTone.toc;
    case 'info':
    default:
      return InfoBoxTone.info;
  }
}

class ArticleBlock {
  final ArticleBlockType type;
  final Map<String, dynamic> raw;

  const ArticleBlock({required this.type, required this.raw});

  factory ArticleBlock.fromJson(Map<String, dynamic> json) {
    return ArticleBlock(
      type: _typeFromString(json['type']?.toString()),
      raw: json,
    );
  }

  // -- Tip-spesifik getter'lar ----------------------------------------------

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

  /// quote
  String get cite => (raw['cite'] ?? '').toString();

  /// list
  bool get ordered => raw['ordered'] == true;
  List<ArticleListItem> get items {
    final list = raw['items'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((m) => ArticleListItem.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// table
  List<List<ArticleTableCell>> get rows {
    final list = raw['rows'];
    if (list is! List) return const [];
    return list
        .whereType<List>()
        .map((row) => row
            .whereType<Map>()
            .map((m) =>
                ArticleTableCell.fromJson(Map<String, dynamic>.from(m)))
            .toList())
        .toList();
  }

  /// infoBox
  InfoBoxTone get tone => _toneFromString(raw['tone']?.toString());
  String get title => (raw['title'] ?? '').toString();
  List<ArticleBlock> get children {
    final list = raw['children'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((m) => ArticleBlock.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// metricGrid — ardisik nutrition-card / stat-card kumesi.
  /// Her item: buyuk deger (h2-h6) + altina kucuk etiket (p).
  List<ArticleMetricItem> get metrics {
    final list = raw['items'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((m) => ArticleMetricItem.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// cardGrid — ardisik benefit-card / recipe-card kumesi.
  /// Her item: baslik (h2-h6) + bir veya birden cok paragraf + opsiyonel liste.
  List<ArticleCardItem> get cards {
    final list = raw['items'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((m) => ArticleCardItem.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }
}

class ArticleListItem {
  final String text;
  final String html;

  const ArticleListItem({required this.text, required this.html});

  factory ArticleListItem.fromJson(Map<String, dynamic> json) {
    return ArticleListItem(
      text: (json['text'] ?? '').toString(),
      html: (json['html'] ?? '').toString(),
    );
  }
}

class ArticleTableCell {
  final bool header;
  final String text;
  final String html;

  const ArticleTableCell({
    required this.header,
    required this.text,
    required this.html,
  });

  factory ArticleTableCell.fromJson(Map<String, dynamic> json) {
    return ArticleTableCell(
      header: json['header'] == true,
      text: (json['text'] ?? '').toString(),
      html: (json['html'] ?? '').toString(),
    );
  }
}

/// Tek bir metric kart ogesi (nutrition-card / stat-card).
/// value: buyuk sayisal deger (orn. "380" veya "17g")
/// label: altinda gozuken aciklama (orn. "kcal Kalori")
class ArticleMetricItem {
  final String value;
  final String label;

  const ArticleMetricItem({required this.value, required this.label});

  factory ArticleMetricItem.fromJson(Map<String, dynamic> json) {
    return ArticleMetricItem(
      value: (json['value'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
    );
  }
}

/// Tek bir feature kart ogesi (benefit-card / recipe-card).
/// title: kartin basligi (h2-h6)
/// body: kart icindeki paragraflar (inline HTML korunur)
/// list: kart icindeki liste ogeleri (varsa)
class ArticleCardItem {
  final String title;
  final List<ArticleListItem> body;
  final List<ArticleListItem> list;

  const ArticleCardItem({
    required this.title,
    required this.body,
    required this.list,
  });

  factory ArticleCardItem.fromJson(Map<String, dynamic> json) {
    List<ArticleListItem> parseItems(Object? raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((m) => ArticleListItem.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }

    return ArticleCardItem(
      title: (json['title'] ?? '').toString(),
      body: parseItems(json['body']),
      list: parseItems(json['list']),
    );
  }
}
