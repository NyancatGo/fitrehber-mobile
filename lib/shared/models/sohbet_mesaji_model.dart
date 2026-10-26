// ---------------------------------------------------------------------------
// SOHBET MESAJI MODELİ
// ---------------------------------------------------------------------------
// Yapay zekâ asistanı ekranındaki sohbet balonlarının verisini tutar.
// Hem kullanıcının yazdığı mesajları hem de asistanın verdiği yanıtları
// aynı model temsil eder; `role` alanı hangisi olduğunu belirtir.
// Ayrıca asistanın kullandığı bağlam etiketlerini (`contextTags`), önerilen
// takip sorularını (`suggestions`), Besin DB ile doğrulanmış "Öğünüme Ekle"
// eylem kartlarını (`actions`), geri bildirim durumunu (`feedbackRating`) ve
// hata durumunda yeniden deneme bilgisini (`isError`, `failedPrompt`) taşır.
// ---------------------------------------------------------------------------

/// Bir sohbet mesajının kimden geldiğini belirtir.
enum SohbetMesajiRolu {
  /// Mesajı kullanıcı yazdı.
  kullanici,

  /// Mesajı yapay zekâ asistanı üretti.
  asistan,
}

/// Eylem kartı içindeki tek bir doğrulanmış besin kalemini temsil eder.
class AsistanOgunKalemiModel {
  final int? besinId;
  final String isim;
  final double gram;
  final int kalori;
  final double protein;
  final double karbonhidrat;
  final double yag;
  final bool dogrulanmis;

  const AsistanOgunKalemiModel({
    this.besinId,
    required this.isim,
    required this.gram,
    required this.kalori,
    required this.protein,
    required this.karbonhidrat,
    required this.yag,
    this.dogrulanmis = true,
  });

  factory AsistanOgunKalemiModel.fromJson(Map<String, dynamic> json) {
    return AsistanOgunKalemiModel(
      besinId: (json['besin_id'] as num?)?.toInt(),
      isim: json['isim']?.toString().trim() ?? '',
      gram: (json['gram'] as num?)?.toDouble() ?? 100.0,
      kalori: (json['kalori'] as num?)?.toInt() ?? 0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0.0,
      karbonhidrat: (json['karbonhidrat'] as num?)?.toDouble() ?? 0.0,
      yag: (json['yag'] as num?)?.toDouble() ?? 0.0,
      dogrulanmis: json['dogrulanmis'] != false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (besinId != null) 'besin_id': besinId,
      'isim': isim,
      'gram': gram,
      'kalori': kalori,
      'protein': protein,
      'karbonhidrat': karbonhidrat,
      'yag': yag,
      'dogrulanmis': dogrulanmis,
    };
  }
}

/// Asistanın yanıtıyla birlikte dönen ve tek dokunuşla beslenme günlüğüne
/// eklenebilen doğrulanmış öğün eylem kartı modeli.
class AsistanEylemKartiModel {
  final String type;
  final String ogunTipi;
  final String baslik;
  final List<AsistanOgunKalemiModel> besinler;
  final int toplamKalori;
  final double toplamProtein;
  final double toplamKarbonhidrat;
  final double toplamYag;
  final bool uygulandi;

  const AsistanEylemKartiModel({
    this.type = 'ogun_ekle',
    required this.ogunTipi,
    required this.baslik,
    required this.besinler,
    required this.toplamKalori,
    required this.toplamProtein,
    required this.toplamKarbonhidrat,
    required this.toplamYag,
    this.uygulandi = false,
  });

  String get ogunEtiketi {
    switch (ogunTipi) {
      case 'sabah':
        return 'Kahvaltı';
      case 'ogle':
        return 'Öğle Yemeği';
      case 'aksam':
        return 'Akşam Yemeği';
      default:
        return 'Atıştırmalık';
    }
  }

  factory AsistanEylemKartiModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['besinler'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (e) => AsistanOgunKalemiModel.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .where((i) => i.isim.isNotEmpty && i.gram > 0)
              .toList(growable: false)
        : const <AsistanOgunKalemiModel>[];

    final toplam = json['toplam'] is Map
        ? Map<String, dynamic>.from(json['toplam'] as Map)
        : const <String, dynamic>{};

    final topKcal =
        (toplam['kalori'] as num?)?.toInt() ??
        items.fold<int>(0, (s, i) => s + i.kalori);
    final topProt =
        (toplam['protein'] as num?)?.toDouble() ??
        items.fold<double>(0, (s, i) => s + i.protein);
    final topKarb =
        (toplam['karbonhidrat'] as num?)?.toDouble() ??
        items.fold<double>(0, (s, i) => s + i.karbonhidrat);
    final topYag =
        (toplam['yag'] as num?)?.toDouble() ??
        items.fold<double>(0, (s, i) => s + i.yag);

    return AsistanEylemKartiModel(
      type: json['type']?.toString() ?? 'ogun_ekle',
      ogunTipi: json['ogun_tipi']?.toString() ?? 'aksam',
      baslik: json['baslik']?.toString() ?? 'Önerilen Öğün',
      besinler: items,
      toplamKalori: topKcal,
      toplamProtein: topProt,
      toplamKarbonhidrat: topKarb,
      toplamYag: topYag,
      uygulandi: json['uygulandi'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'ogun_tipi': ogunTipi,
      'baslik': baslik,
      'besinler': besinler.map((e) => e.toJson()).toList(),
      'toplam': {
        'kalori': toplamKalori,
        'protein': toplamProtein,
        'karbonhidrat': toplamKarbonhidrat,
        'yag': toplamYag,
      },
      'uygulandi': uygulandi,
    };
  }

  AsistanEylemKartiModel copyWith({bool? uygulandi}) {
    return AsistanEylemKartiModel(
      type: type,
      ogunTipi: ogunTipi,
      baslik: baslik,
      besinler: besinler,
      toplamKalori: toplamKalori,
      toplamProtein: toplamProtein,
      toplamKarbonhidrat: toplamKarbonhidrat,
      toplamYag: toplamYag,
      uygulandi: uygulandi ?? this.uygulandi,
    );
  }
}

/// Kullanıcının günlük AI mesaj kotası durumu.
class AsistanKotaModel {
  final int used;
  final int limit;
  final int remaining;

  const AsistanKotaModel({
    required this.used,
    required this.limit,
    required this.remaining,
  });

  factory AsistanKotaModel.fromJson(Map<String, dynamic> json) {
    final used = (json['used'] as num?)?.toInt() ?? 0;
    final limit = (json['limit'] as num?)?.toInt() ?? 80;
    final remaining =
        (json['remaining'] as num?)?.toInt() ?? (limit - used).clamp(0, limit);
    return AsistanKotaModel(used: used, limit: limit, remaining: remaining);
  }
}

/// AI asistan API'sinden dönen zenginleştirilmiş yanıt modeli.
class AsistanYanitModel {
  /// Asistanın ürettiği Markdown metin yanıtı.
  final String answer;

  /// Yanıtın altında gösterilecek bağlamsal takip sorusu önerileri.
  final List<String> suggestions;

  /// Yanıt üretilirken analiz edilen veri kaynakları (ör. Profil, Bugünkü Beslenme).
  final List<String> contextTags;

  /// Yanıtla birlikte dönen doğrulanmış eylem kartları ("Öğünüme Ekle").
  final List<AsistanEylemKartiModel> actions;

  /// Yanıtın benzersiz kimliği (geri bildirim ve analitik eşleştirmesi için).
  final String? messageId;

  /// Günlük mesaj kotası bilgisi.
  final AsistanKotaModel? quota;

  /// Güvenlik katmanı kategorisi (varsa).
  final String? safetyCategory;

  /// Yanıtın uzunluk sınırına takılıp takılmadığı.
  final bool truncated;

  const AsistanYanitModel({
    required this.answer,
    this.suggestions = const [],
    this.contextTags = const [],
    this.actions = const [],
    this.messageId,
    this.quota,
    this.safetyCategory,
    this.truncated = false,
  });

  factory AsistanYanitModel.fromJson(Map<String, dynamic> json) {
    final answer = json['answer']?.toString().trim() ?? '';
    final meta = json['meta'] is Map
        ? Map<String, dynamic>.from(json['meta'] as Map)
        : const <String, dynamic>{};

    List<String> listeOku(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .map((e) => e?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList(growable: false);
    }

    List<AsistanEylemKartiModel> eylemleriOku(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map(
            (e) =>
                AsistanEylemKartiModel.fromJson(Map<String, dynamic>.from(e)),
          )
          .where((a) => a.besinler.isNotEmpty)
          .toList(growable: false);
    }

    final suggestions = listeOku(json['suggestions'] ?? meta['suggestions']);
    final contextTags = listeOku(json['context_tags'] ?? meta['context_tags']);
    final actions = eylemleriOku(json['actions'] ?? meta['actions']);
    final truncated = meta['truncated'] == true;
    final messageId = meta['message_id']?.toString();
    final safetyCategory = meta['safety']?.toString();
    final quotaRaw = meta['quota'] ?? json['quota'];
    final quota = quotaRaw is Map
        ? AsistanKotaModel.fromJson(Map<String, dynamic>.from(quotaRaw))
        : null;

    return AsistanYanitModel(
      answer: answer,
      suggestions: suggestions,
      contextTags: contextTags,
      actions: actions,
      messageId: messageId,
      quota: quota,
      safetyCategory: safetyCategory,
      truncated: truncated,
    );
  }
}

/// AI asistan sohbetindeki tek bir mesajı temsil eden veri modeli.
class SohbetMesajiModel {
  /// Mesajın metin içeriği.
  final String text;

  /// Mesajın sahibi (kullanıcı mı, asistan mı).
  final SohbetMesajiRolu role;

  /// Mesajın oluşturulduğu an.
  final DateTime timestamp;

  /// Bu mesajın, sonraki API isteklerine "sohbet geçmişi" olarak
  /// eklenip eklenmeyeceği. Örneğin hata baloncukları geçmişe katılmaz.
  final bool includeInHistory;

  /// Bu mesaj bir hata bildirimi mi?
  final bool isError;

  /// Hata mesajıysa, kullanıcının tek dokunuşla tekrar gönderebileceği orijinal soru.
  final String? failedPrompt;

  /// Asistan mesajının altında tek dokunuşla sorulabilecek takip soruları.
  final List<String> suggestions;

  /// Bu yanıt üretilirken kullanılan kullanıcı verisi etiketleri.
  final List<String> contextTags;

  /// Yanıtla birlikte sunulan doğrulanmış eylem kartları ("Öğünüme Ekle").
  final List<AsistanEylemKartiModel> actions;

  /// Sunucu tarafından üretilen mesaj kimliği (👍/👎 geri bildirimi için).
  final String? messageId;

  /// Kullanıcının bu yanıta verdiği geri bildirim ('up' veya 'down').
  final String? feedbackRating;

  const SohbetMesajiModel({
    required this.text,
    required this.role,
    required this.timestamp,
    this.includeInHistory = true,
    this.isError = false,
    this.failedPrompt,
    this.suggestions = const [],
    this.contextTags = const [],
    this.actions = const [],
    this.messageId,
    this.feedbackRating,
  });

  /// Mesajı kullanıcının yazıp yazmadığını kısa yoldan döndürür.
  bool get isUser => role == SohbetMesajiRolu.kullanici;

  /// Mesajı, AI API'sinin beklediği `{role, content}` biçimine çevirir.
  Map<String, String> toApiJson() {
    return {'role': isUser ? 'user' : 'assistant', 'content': text};
  }

  /// Yerel önbellekte (SharedPreferences) saklamak için JSON haritasına dönüştürür.
  Map<String, dynamic> toStorageJson() {
    return {
      'text': text,
      'role': isUser ? 'user' : 'assistant',
      'timestamp': timestamp.toIso8601String(),
      'includeInHistory': includeInHistory,
      'isError': isError,
      if (failedPrompt != null) 'failedPrompt': failedPrompt,
      if (suggestions.isNotEmpty) 'suggestions': suggestions,
      if (contextTags.isNotEmpty) 'contextTags': contextTags,
      if (actions.isNotEmpty)
        'actions': actions.map((a) => a.toJson()).toList(),
      if (messageId != null) 'messageId': messageId,
      if (feedbackRating != null) 'feedbackRating': feedbackRating,
    };
  }

  /// Yerel önbellekten (SharedPreferences) mesaj nesnesini geri yükler.
  factory SohbetMesajiModel.fromStorageJson(Map<String, dynamic> json) {
    final roleStr = json['role']?.toString() ?? 'assistant';
    final parsedTime = DateTime.tryParse(json['timestamp']?.toString() ?? '');

    List<String> listeOku(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .map((e) => e?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList(growable: false);
    }

    List<AsistanEylemKartiModel> eylemleriOku(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map(
            (e) =>
                AsistanEylemKartiModel.fromJson(Map<String, dynamic>.from(e)),
          )
          .where((a) => a.besinler.isNotEmpty)
          .toList(growable: false);
    }

    return SohbetMesajiModel(
      text: json['text']?.toString() ?? '',
      role: roleStr == 'user'
          ? SohbetMesajiRolu.kullanici
          : SohbetMesajiRolu.asistan,
      timestamp: parsedTime ?? DateTime.now(),
      includeInHistory: json['includeInHistory'] != false,
      isError: json['isError'] == true,
      failedPrompt: json['failedPrompt']?.toString(),
      suggestions: listeOku(json['suggestions']),
      contextTags: listeOku(json['contextTags']),
      actions: eylemleriOku(json['actions']),
      messageId: json['messageId']?.toString(),
      feedbackRating: json['feedbackRating']?.toString(),
    );
  }

  SohbetMesajiModel copyWith({
    String? text,
    SohbetMesajiRolu? role,
    DateTime? timestamp,
    bool? includeInHistory,
    bool? isError,
    String? failedPrompt,
    List<String>? suggestions,
    List<String>? contextTags,
    List<AsistanEylemKartiModel>? actions,
    String? messageId,
    String? feedbackRating,
  }) {
    return SohbetMesajiModel(
      text: text ?? this.text,
      role: role ?? this.role,
      timestamp: timestamp ?? this.timestamp,
      includeInHistory: includeInHistory ?? this.includeInHistory,
      isError: isError ?? this.isError,
      failedPrompt: failedPrompt ?? this.failedPrompt,
      suggestions: suggestions ?? this.suggestions,
      contextTags: contextTags ?? this.contextTags,
      actions: actions ?? this.actions,
      messageId: messageId ?? this.messageId,
      feedbackRating: feedbackRating ?? this.feedbackRating,
    );
  }
}
