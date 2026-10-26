// ---------------------------------------------------------------------------
// AI ASİSTAN DURUM YÖNETİMİ (RIVERPOD)
// ---------------------------------------------------------------------------
// Yapay zekâ asistanı sohbetinin durumunu yönetir: mesaj listesi, yükleme
// durumu, yerel sohbet geçmişi saklama (SharedPreferences), çevrimdışı
// beslenme kuyruğu senkronu, canlı kullanıcı bağlamı üretimi, takip sorusu
// önerileri, "Öğünüme Ekle" eylem kartı uygulaması, 👍/👎 geri bildirimleri,
// günlük kota bilgisi ve hata durumunda tek dokunuşla yeniden deneme.
// ---------------------------------------------------------------------------

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/api_servisi.dart';
import '../../../shared/models/beslenme_model.dart';
import '../../../shared/models/profil_model.dart';
import '../../../shared/models/sohbet_mesaji_model.dart';
import '../../../shared/oturum_denetleyici.dart';
import '../../../shared/utils/beslenme_hesaplayici.dart';
import '../../beslenme/providers/beslenme_provider.dart';

/// API'ye gönderilen sohbet geçmişinde tutulacak en fazla mesaj sayısı.
const int _maxHistoryMessages = 10;

/// Yerel depoda (SharedPreferences) saklanacak maksimum mesaj sayısı.
const int _maxPersistedMessages = 30;

const String _varsayilanKarsilamaMetni =
    'Merhaba! Ben FitRehber AI Asistanı. Beslenme, antrenman veya genel sağlık konularında sana nasıl yardımcı olabilirim?';

/// AI asistan sohbetinin anlık durumunu (mesajlar + yükleme + günlük kota) temsil eder.
class AsistanDurumu {
  /// Sohbetteki tüm mesajlar (kullanıcı + asistan).
  final List<SohbetMesajiModel> messages;

  /// Asistandan yanıt bekleniyor mu?
  final bool isLoading;

  /// Kullanıcının günlük AI mesaj kotası (sunucudan döndüyse).
  final AsistanKotaModel? gunlukKota;

  AsistanDurumu({
    required this.messages,
    this.isLoading = false,
    this.gunlukKota,
  });

  AsistanDurumu copyWith({
    List<SohbetMesajiModel>? messages,
    bool? isLoading,
    AsistanKotaModel? gunlukKota,
  }) {
    return AsistanDurumu(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      gunlukKota: gunlukKota ?? this.gunlukKota,
    );
  }
}

/// Sohbet mesajlarının gönderilmesini ve durumun güncellenmesini yöneten kontrolcü.
///
/// Her örnek TEK bir kullanıcıya bağlıdır: kalıcı geçmiş anahtarı
/// oluşturulurken sabitlenir ([_kullaniciId]). Anahtar her yazmada oturumdan
/// yeniden okunmadığı için, A kullanıcısının bellekteki sohbeti B oturum
/// açtıktan sonra B'nin kalıcı geçmişine ASLA yazılamaz.
class AsistanDenetleyici extends StateNotifier<AsistanDurumu> {
  final ApiServisi _api;
  final Ref? _ref;
  final bool _kaliciDepoKullan;

  /// Bu denetleyicinin ait olduğu kullanıcı (geçerli değilse `null`).
  final int? _kullaniciId;

  AsistanDenetleyici({
    ApiServisi? api,
    Ref? ref,
    int? kullaniciId,
    bool kaliciDepoKullan = true,
  }) : _api = api ?? ApiServisi.instance,
       _ref = ref,
       _kullaniciId = _gecerliKullaniciId(
         kullaniciId ?? ref?.read(oturumDenetleyiciProvider).profile?.id,
       ),
       _kaliciDepoKullan = kaliciDepoKullan,
       super(AsistanDurumu(messages: [_karsilamaMesaji()])) {
    if (_kaliciDepoKullan) {
      _gecmisiYukle();
    }
  }

  static int? _gecerliKullaniciId(int? id) =>
      (id != null && id > 0) ? id : null;

  static SohbetMesajiModel _karsilamaMesaji() {
    return SohbetMesajiModel(
      text: _varsayilanKarsilamaMetni,
      role: SohbetMesajiRolu.asistan,
      timestamp: DateTime.now(),
      includeInHistory: false,
    );
  }

  /// Kalıcı sohbet geçmişi anahtarı; kalıcı saklama yapılmayacaksa `null`.
  ///
  /// Uygulamada (Riverpod `ref` mevcut) geçerli bir kullanıcı yoksa geçmiş
  /// hiç yazılmaz — ortak bir "genel" anahtara düşmek hesaplar arası sızıntı
  /// yaratırdı. `ref` olmadan (yalın kullanım/test) "genel" anahtarı kullanılır.
  String? get _storageKey {
    final userId = _kullaniciId;
    if (userId != null) return 'ai_sohbet_gecmisi_v1_$userId';
    if (_ref == null) return 'ai_sohbet_gecmisi_v1_genel';
    return null;
  }

  Future<void> _gecmisiYukle() async {
    final anahtar = _storageKey;
    if (anahtar == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(anahtar);
      if (raw == null || raw.trim().isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      final yuklenen = decoded
          .whereType<Map>()
          .map(
            (item) => SohbetMesajiModel.fromStorageJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .where((m) => m.text.trim().isNotEmpty)
          .toList();

      if (yuklenen.isNotEmpty && mounted) {
        // Yalnızca kullanıcı henüz yeni bir mesaj göndermediyse geçmişi uygula.
        final kullaniciYazdiMi = state.messages.any((m) => m.isUser);
        if (!kullaniciYazdiMi && !state.isLoading) {
          state = state.copyWith(messages: yuklenen);
        }
      }
    } catch (e) {
      debugPrint('[AsistanDenetleyici._gecmisiYukle] $e');
    }
  }

  Future<void> _gecmisiKaydet(List<SohbetMesajiModel> messages) async {
    if (!_kaliciDepoKullan) return;
    final anahtar = _storageKey;
    if (anahtar == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final kaliciListe = messages.where((m) => !m.isError).toList();
      final kirpilmis = kaliciListe.length > _maxPersistedMessages
          ? kaliciListe.sublist(kaliciListe.length - _maxPersistedMessages)
          : kaliciListe;

      final encoded = jsonEncode(
        kirpilmis.map((m) => m.toStorageJson()).toList(),
      );
      await prefs.setString(anahtar, encoded);
    } catch (e) {
      debugPrint('[AsistanDenetleyici._gecmisiKaydet] $e');
    }
  }

  /// Kullanıcının yazdığı [text] mesajını asistana gönderir ve yanıtı bekler.
  ///
  /// Boş mesaj veya hâlihazırda yanıt beklenirken çağrılırsa hiçbir şey yapmaz.
  Future<void> sendMessage(String text) async {
    final temizMetin = text.trim();
    if (temizMetin.isEmpty || state.isLoading) return;

    final history = _recentHistory();

    // Kullanıcı mesajını listeye ekle ve yükleme durumunu aç.
    final userMessage = SohbetMesajiModel(
      text: temizMetin,
      role: SohbetMesajiRolu.kullanici,
      timestamp: DateTime.now(),
    );

    final yeniMesajlar = [...state.messages, userMessage];
    state = state.copyWith(messages: yeniMesajlar, isLoading: true);
    await _gecmisiKaydet(yeniMesajlar);

    // Çevrimdışı kuyrukta bekleyen öğün/su işlemi varsa AI okumadan önce sunucuya ilet.
    await _bekleyenBeslenmeVerisiniSenkronla();

    final clientContext = _canliBaglamOzetiOlustur();

    try {
      final yanit = await _api.asistanaDetayliSor(
        message: temizMetin,
        history: history,
        clientContext: clientContext,
      );

      final kullanilanEtiketler = yanit.contextTags.isNotEmpty
          ? yanit.contextTags
          : _yerelBaglamEtiketleriUret(temizMetin, history);

      final takipOnerileri = yanit.suggestions.isNotEmpty
          ? yanit.suggestions
          : _yerelTakipOnerileriUret(temizMetin);

      final aiMessage = SohbetMesajiModel(
        text: yanit.answer,
        role: SohbetMesajiRolu.asistan,
        timestamp: DateTime.now(),
        suggestions: takipOnerileri,
        contextTags: kullanilanEtiketler,
        actions: yanit.actions,
        messageId: yanit.messageId,
      );

      if (!mounted) return;
      final guncelListe = [...state.messages, aiMessage];
      state = state.copyWith(
        messages: guncelListe,
        isLoading: false,
        gunlukKota: yanit.quota ?? state.gunlukKota,
      );
      await _gecmisiKaydet(guncelListe);
    } catch (e) {
      if (!mounted) return;
      final temizHata = _temizHataMesaji(e);
      final errorMessage = SohbetMesajiModel(
        text: 'Yanıt alınamadı: $temizHata',
        role: SohbetMesajiRolu.asistan,
        timestamp: DateTime.now(),
        includeInHistory: false,
        isError: true,
        failedPrompt: temizMetin,
      );

      state = state.copyWith(
        messages: [...state.messages, errorMessage],
        isLoading: false,
      );
    }
  }

  /// Asistanın önerdiği eylem kartındaki ("Öğünüme Ekle") besinleri seçili
  /// günün ilgili öğününe kaydeder ve kartı `uygulandi = true` olarak işaretler.
  Future<bool> eylemKartiniUygula(
    SohbetMesajiModel mesaj, {
    int eylemIndex = 0,
  }) async {
    if (eylemIndex < 0 || eylemIndex >= mesaj.actions.length) return false;
    final eylem = mesaj.actions[eylemIndex];
    if (eylem.uygulandi || eylem.besinler.isEmpty) return false;

    final ref = _ref;
    if (ref != null) {
      final beslenmeNotifier = ref.read(beslenmeProvider.notifier);
      for (final kalem in eylem.besinler) {
        final basarili = await beslenmeNotifier.ogunEkle(
          ogunTipi: eylem.ogunTipi,
          besinId: kalem.besinId,
          besinIsim: kalem.isim,
          miktar: kalem.gram,
          kalori: kalem.kalori,
          protein: kalem.protein,
          karbonhidrat: kalem.karbonhidrat,
          yag: kalem.yag,
        );
        if (!basarili) return false;
      }
    }

    final guncelEylemler = List<AsistanEylemKartiModel>.from(mesaj.actions);
    guncelEylemler[eylemIndex] = eylem.copyWith(uygulandi: true);
    final guncelMesaj = mesaj.copyWith(actions: guncelEylemler);
    _mesajiGuncelle(mesaj, guncelMesaj);

    if (mesaj.messageId != null && mesaj.messageId!.isNotEmpty) {
      _api.asistanGeriBildirimGonder(
        messageId: mesaj.messageId!,
        actionApplied: true,
      );
    }
    return true;
  }

  /// Bir asistan yanıtına 👍 (`'up'`) veya 👎 (`'down'`) geri bildirimi kaydeder.
  Future<void> geriBildirimVer(
    SohbetMesajiModel mesaj,
    String rating, {
    String? reason,
  }) async {
    if (mesaj.isUser || mesaj.isError) return;
    if (rating != 'up' && rating != 'down') return;

    final guncelMesaj = mesaj.copyWith(feedbackRating: rating);
    _mesajiGuncelle(mesaj, guncelMesaj);

    if (mesaj.messageId != null && mesaj.messageId!.isNotEmpty) {
      await _api.asistanGeriBildirimGonder(
        messageId: mesaj.messageId!,
        rating: rating,
        reason: reason,
      );
    }
  }

  void _mesajiGuncelle(SohbetMesajiModel eski, SohbetMesajiModel yeni) {
    final mevcut = List<SohbetMesajiModel>.from(state.messages);
    final idx = mevcut.indexOf(eski);
    if (idx == -1) return;
    mevcut[idx] = yeni;
    state = state.copyWith(messages: mevcut);
    _gecmisiKaydet(mevcut);
  }

  /// Hata almış bir mesajı tek dokunuşla yeniden gönderir.
  Future<void> yenidenDene(SohbetMesajiModel hataMesaji) async {
    if (state.isLoading) return;
    final soru = hataMesaji.failedPrompt?.trim();
    if (soru == null || soru.isEmpty) return;

    final mevcut = List<SohbetMesajiModel>.from(state.messages);
    final errIdx = mevcut.indexOf(hataMesaji);
    if (errIdx != -1) {
      mevcut.removeAt(errIdx);
      if (errIdx > 0 &&
          mevcut[errIdx - 1].isUser &&
          mevcut[errIdx - 1].text == soru) {
        mevcut.removeAt(errIdx - 1);
      }
      state = state.copyWith(messages: mevcut);
    }

    await sendMessage(soru);
  }

  /// Sohbet geçmişini sıfırlayıp karşılama durumuna döner.
  Future<void> sohbetiTemizle() async {
    if (state.isLoading) return;
    final ilkMesajlar = [_karsilamaMesaji()];
    state = AsistanDurumu(
      messages: ilkMesajlar,
      gunlukKota: state.gunlukKota,
    );
    final anahtar = _storageKey;
    if (_kaliciDepoKullan && anahtar != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(anahtar);
      } catch (e) {
        debugPrint('[AsistanDenetleyici.sohbetiTemizle] $e');
      }
    }
  }

  Future<void> _bekleyenBeslenmeVerisiniSenkronla() async {
    final ref = _ref;
    if (ref == null) return;
    try {
      final beslenmeState = ref.read(beslenmeProvider);
      if (beslenmeState.bekleyenIslemSayisi > 0) {
        // Kuyruk, kullanıcıya bağlı beslenme denetleyicisi üzerinden
        // boşaltılır; böylece sahiplik denetimi ve kullanıcı izolasyonu korunur.
        await ref
            .read(beslenmeProvider.notifier)
            .bekleyenleriSenkronla()
            .timeout(const Duration(seconds: 2));
      }
    } catch (_) {
      // Çevrimdışıysa veya zaman aşımına uğrarsa sessizce devam et;
      // clientContext zaten güncel yerel veriyi taşır.
    }
  }

  /// Mobil istemcideki anlık profil + günlük beslenme + öğün kayıtlarını
  /// kompakt bir metin olarak özetler.
  String? _canliBaglamOzetiOlustur() {
    final ref = _ref;
    if (ref == null) return null;

    try {
      final profile = ref.read(oturumDenetleyiciProvider).profile;
      final beslenme = ref.read(beslenmeProvider);
      final veri = beslenme.veri;
      final hedefler = profile != null
          ? BeslenmeHesaplayici.calculate(profile)
          : beslenme.hedefler;

      final satirlar = <String>[];
      if (veri != null) {
        final kalanKcal = hedefler.kaloriHedef - veri.kaloriKcal;
        final kalanProt = (hedefler.proteinHedefG - veri.proteinG).round();
        final kalanSu = hedefler.suHedefMl - veri.suMl;
        satirlar.add(
          'Tarih (${veri.tarih}) toplam: ${veri.kaloriKcal}/${hedefler.kaloriHedef} kcal '
          '(kalan: $kalanKcal kcal), '
          'protein ${veri.proteinG.toStringAsFixed(0)}/${hedefler.proteinHedefG.round()} g '
          '(kalan: $kalanProt g), '
          'karbonhidrat ${veri.karbonhidratG.toStringAsFixed(0)} g, '
          'yağ ${veri.yagG.toStringAsFixed(0)} g, '
          'su ${veri.suMl}/${hedefler.suHedefMl} ml (kalan: $kalanSu ml).',
        );

        final ogunOzeti = <String>[];
        for (final entry in veri.ogunler.entries) {
          if (entry.value.isNotEmpty) {
            final besinler = entry.value
                .take(6)
                .map(
                  (k) =>
                      '${k.besinIsim} (${k.kalori} kcal, ${k.protein.toStringAsFixed(0)}g P)',
                )
                .join(', ');
            ogunOzeti.add('${entry.key}: $besinler');
          }
        }
        if (ogunOzeti.isNotEmpty) {
          satirlar.add('Kayıtlı öğünler: ${ogunOzeti.join(' | ')}.');
        }
      }

      if (satirlar.isEmpty) return null;
      final birlesik = satirlar.join('\n');
      return birlesik.length <= 1400 ? birlesik : birlesik.substring(0, 1400);
    } catch (_) {
      return null;
    }
  }

  List<String> _yerelBaglamEtiketleriUret(
    String message,
    List<SohbetMesajiModel> history,
  ) {
    final norm = _normalize(message);
    final selamlamaMi =
        norm == 'merhaba' || norm == 'selam' || norm == 'nasilsin';
    if (selamlamaMi) return const [];

    final tags = <String>[];
    final profile = _ref?.read(oturumDenetleyiciProvider).profile;
    if (profile != null) {
      tags.add('Profil & Hedefler');
    }

    final beslenmeKelimesiVar = RegExp(
      r'(kalori|protein|karb|makro|yag|su|ogun|yemek|kahvalt|sabah|ogle|aksam|atistir|beslenme|diyet|tarif|menu|acik|eksik|kalan|yedim|yesem)',
    ).hasMatch(norm);

    if (beslenmeKelimesiVar) {
      if (norm.contains('30 gun') || norm.contains('gecen ay')) {
        tags.add('30 Günlük Trend');
      } else if (norm.contains('7 gun') || norm.contains('hafta')) {
        tags.add('7 Günlük Trend');
      } else if (norm.contains('dun')) {
        tags.add('Dünkü Beslenme');
      } else {
        tags.add('Bugünkü Beslenme');
      }
      if (RegExp(
        r'(ogun|yemek|kahvalt|sabah|ogle|aksam|yedim|yesem|menu|tarif)',
      ).hasMatch(norm)) {
        tags.add('Öğün Kayıtları');
      }
    }
    return tags;
  }

  List<String> _yerelTakipOnerileriUret(String message) {
    final ref = _ref;
    ProfilModel? profile;
    GunlukBeslenmeModel? veri;
    BeslenmeHedefleri hedefler = BeslenmeHedefleri.defaults;

    if (ref != null) {
      try {
        profile = ref.read(oturumDenetleyiciProvider).profile;
        final beslenme = ref.read(beslenmeProvider);
        veri = beslenme.veri;
        hedefler = profile != null
            ? BeslenmeHesaplayici.calculate(profile)
            : beslenme.hedefler;
      } catch (_) {}
    }

    final oneriler = <String>[];
    if (veri != null) {
      final kalanProt = (hedefler.proteinHedefG - veri.proteinG).round();
      final kalanKcal = hedefler.kaloriHedef - veri.kaloriKcal;
      if (kalanProt > 20) {
        oneriler.add(
          'Kalan ${kalanProt}g protein açığımı hangi besinlerle kapatabilirim?',
        );
      } else if (kalanKcal > 250) {
        oneriler.add(
          'Bugün kalan $kalanKcal kcal için dengeli bir öğün önerir misin?',
        );
      }
    }

    final hedef = (profile?.goal ?? '').toLowerCase();
    if (hedef.contains('yağ') || hedef.contains('kilo ver')) {
      oneriler.add('Yağ yakımını destekleyen tok tutucu akşam öğünü öner');
    } else if (hedef.contains('kas') || hedef.contains('bulk')) {
      oneriler.add('Kas gelişimi için antrenman sonrası ideal öğün nedir?');
    }

    const varsayilanlar = [
      'Bugün yediklerimi değerlendir ve eksik makrolarımı tamamla',
      'Son 7 gün beslenme performansım nasıl?',
      'Hedefime uygun yarınki örnek menüyü çıkarır mısın?',
    ];

    final soruNorm = _normalize(message);
    final sonuc = <String>[];
    for (final s in [...oneriler, ...varsayilanlar]) {
      if (_normalize(s) != soruNorm && !sonuc.contains(s)) {
        sonuc.add(s);
      }
      if (sonuc.length == 3) break;
    }
    return sonuc;
  }

  static String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .trim();
  }

  static String _temizHataMesaji(Object e) {
    final raw = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
    if (raw.isEmpty) {
      return 'Lütfen internet bağlantını kontrol edip tekrar dene.';
    }
    if (raw.contains('SocketException') ||
        raw.contains('Connection') ||
        raw.contains('XMLHttpRequest') ||
        raw.contains('connection error')) {
      return 'İnternet bağlantısı kurulamadı. Bağlantını kontrol edip tekrar dene.';
    }
    return raw;
  }

  /// API'ye gönderilecek sohbet geçmişini hazırlar: geçmişe dâhil edilen
  /// mesajların yalnızca son [_maxHistoryMessages] tanesi alınır.
  List<SohbetMesajiModel> _recentHistory() {
    final history = state.messages
        .where((message) => message.includeInHistory && !message.isError)
        .toList();
    if (history.length <= _maxHistoryMessages) return history;
    return history.sublist(history.length - _maxHistoryMessages);
  }
}

/// AI asistan sohbetinin durumunu sağlayan provider.
///
/// Oturumdaki kullanıcı kimliğini İZLER (`select`): çıkışta (id -> null) veya
/// hesap değişiminde (id A -> B) denetleyici atılıp yeniden oluşturulur.
/// Böylece A'nın sohbeti bellekte kalıp B'ye gösterilemez veya B'nin kalıcı
/// geçmişine kopyalanamaz — çıkış hangi yoldan yapılırsa yapılsın.
final asistanProvider =
    StateNotifierProvider<AsistanDenetleyici, AsistanDurumu>((ref) {
      final kullaniciId = ref.watch(
        oturumDenetleyiciProvider.select((s) => s.profile?.id),
      );
      return AsistanDenetleyici(
        api: ref.watch(apiServisiProvider),
        ref: ref,
        kullaniciId: kullaniciId,
      );
    });
