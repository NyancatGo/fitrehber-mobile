// ---------------------------------------------------------------------------
// BESLENME YEREL DEPO VE ÇEVRİMDIŞI KUYRUK (OUTBOX)
// ---------------------------------------------------------------------------
// Günlük beslenme/su özetlerini tarihe göre SharedPreferences'ta önbelleğe
// alır ve çevrimdışıyken yapılan öğün/su değişikliklerini kalıcı bir kuyrukta
// (outbox) saklar. Bağlantı geri geldiğinde kuyruk sırayla sunucuya boşaltılır.
//
// ÇOK KULLANICILI İZOLASYON: Tüm anahtarlar kullanıcı kimliğiyle (userId)
// ad alanına ayrılır. Böylece aynı cihazda oturum açan B kullanıcısı,
// A kullanıcısının önbelleğini göremez ve A'nın bekleyen öğünleri B'nin
// token'ıyla sunucuya ASLA yazılmaz. A'nın gönderilmemiş kuyruğu kendi
// anahtarında korunur ve A tekrar giriş yaptığında senkronlanır.
// ---------------------------------------------------------------------------

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_servisi.dart';
import '../models/beslenme_model.dart';

/// Beslenme ekranı için yerel önbellek ve çevrimdışı yazma kuyruğu servisi.
class BeslenmeYerelDepo {
  static final BeslenmeYerelDepo instance = BeslenmeYerelDepo();

  static const String _gunCachePrefix = 'beslenme_gun_cache_v2_';
  static const String _outboxPrefix = 'beslenme_outbox_v2_';
  static const String _geciciIdSayacKey = 'beslenme_outbox_seq_v1';

  /// Kullanıcı ayrımı OLMAYAN eski (v1) anahtarlar. Sahibi bilinemediği için
  /// hiçbir kullanıcıya atanmaz; ilk erişimde güvenli biçimde silinir.
  @visibleForTesting
  static const String eskiGunCachePrefix = 'beslenme_gun_cache_v1_';
  @visibleForTesting
  static const String eskiOutboxKey = 'beslenme_outbox_v1';

  /// Verilen kullanıcının günlük önbellek anahtarı.
  @visibleForTesting
  static String gunAnahtari(int kullaniciId, String tarih) =>
      '$_gunCachePrefix${kullaniciId}_$tarih';

  /// Verilen kullanıcının outbox anahtarı.
  @visibleForTesting
  static String outboxAnahtari(int kullaniciId) => '$_outboxPrefix$kullaniciId';

  /// Kullanıcı başına tek uçuş (single-flight) boşaltma kilidi.
  final Map<int, Future<void>> _bosaltmaUcuslari = {};

  bool _eskiAnahtarlarTemizlendi = false;

  /// Verilen hatanın ağ/bağlantı kaynaklı geçici bir hata olup olmadığını döner.
  ///
  /// Bağlantı/zaman aşımı durumlarında `DioException` oluşur. Bu kontrol,
  /// kullanıcı işleminin çevrimdışı kuyruğa alınıp alınmayacağına karar verir.
  static bool agHatasiMi(Object hata) {
    if (hata is DioException) {
      return hata.type == DioExceptionType.connectionError ||
          hata.type == DioExceptionType.connectionTimeout ||
          hata.type == DioExceptionType.sendTimeout ||
          hata.type == DioExceptionType.receiveTimeout ||
          hata.type == DioExceptionType.unknown;
    }
    return false;
  }

  /// Kuyruktaki bir işlemin KALICI olarak başarısız olup olmadığını döner.
  ///
  /// Güvenli varsayılan: yalnızca kesin olarak kalıcı olduğu bilinen hatalarda
  /// `true` döner; bilinmeyen her hata (ağ, 401, 429, 5xx, tanınmayan tipler)
  /// geçici sayılır ve işlem kuyrukta KORUNUR. Kuyruğun geçici olarak takılması
  /// kabul edilebilir; kullanıcının girdiği verinin sessizce silinmesi edilemez.
  ///
  /// Kalıcı sayılanlar:
  ///   * [ApiHatasi.kaliciMi] — sunucunun içerik nedeniyle reddettiği 4xx
  ///     (400/403/404/409/422 ...). 401 ve 429 bu kapsamda DEĞİLDİR.
  ///   * Yerel kayıt bozulması — kuyruk kaydı ayrıştırılamıyor (tip/format).
  static bool kaliciHataMi(Object hata) {
    if (hata is ApiHatasi) return hata.kaliciMi;
    if (hata is TypeError || hata is FormatException) return true;
    return false;
  }

  static void _kullaniciIdDogrula(int kullaniciId) {
    if (kullaniciId <= 0) {
      throw ArgumentError.value(
        kullaniciId,
        'kullaniciId',
        'Yerel beslenme verisi geçerli bir kullanıcıya bağlanmalıdır.',
      );
    }
  }

  Future<SharedPreferences> _prefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!_eskiAnahtarlarTemizlendi) {
      _eskiAnahtarlarTemizlendi = true;
      await _eskiAnahtarlariTemizle(prefs);
    }
    return prefs;
  }

  Future<void> _eskiAnahtarlariTemizle(SharedPreferences prefs) async {
    try {
      final silinecekler = prefs
          .getKeys()
          .where((k) => k == eskiOutboxKey || k.startsWith(eskiGunCachePrefix))
          .toList();
      for (final anahtar in silinecekler) {
        await prefs.remove(anahtar);
      }
    } catch (e) {
      debugPrint('[BeslenmeYerelDepo._eskiAnahtarlariTemizle] $e');
    }
  }

  /// Verilen günün beslenme modelini kullanıcının yerel önbelleğine yazar.
  Future<void> gunKaydet(int kullaniciId, GunlukBeslenmeModel model) async {
    if (kullaniciId <= 0) return;
    try {
      final prefs = await _prefs();
      await prefs.setString(
        gunAnahtari(kullaniciId, model.tarih),
        jsonEncode(model.toJson()),
      );
    } catch (e) {
      debugPrint('[BeslenmeYerelDepo.gunKaydet] $e');
    }
  }

  /// Verilen tarihin kullanıcıya ait yerel önbellekteki modelini okur; yoksa `null`.
  Future<GunlukBeslenmeModel?> gunOku(int kullaniciId, String tarih) async {
    if (kullaniciId <= 0) return null;
    try {
      final prefs = await _prefs();
      final raw = prefs.getString(gunAnahtari(kullaniciId, tarih));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return GunlukBeslenmeModel.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (e) {
      debugPrint('[BeslenmeYerelDepo.gunOku] $e');
    }
    return null;
  }

  /// Kullanıcının kuyrukta bekleyen çevrimdışı işlem sayısını döner.
  Future<int> bekleyenSayisi(int kullaniciId) async {
    if (kullaniciId <= 0) return 0;
    final liste = await _kuyruguOku(kullaniciId);
    return liste.length;
  }

  /// Çıkış yapan kullanıcının cihazdaki beslenme önbelleğini temizler.
  ///
  /// Günlük özetler sunucudan yeniden üretilebilen kişisel sağlık verisidir;
  /// gizlilik için silinir. Gönderilmemiş outbox ise varsayılan olarak
  /// KORUNUR: kullanıcı anahtarıyla izole olduğu için başka bir hesaba
  /// sızamaz ve kullanıcı tekrar giriş yaptığında sunucuya iletilir.
  /// [kuyruguDaSil] `true` verilirse bekleyen işlemler de kalıcı olarak silinir.
  Future<void> kullaniciVerileriniTemizle(
    int kullaniciId, {
    bool kuyruguDaSil = false,
  }) async {
    try {
      final prefs = await _prefs();
      if (kullaniciId > 0) {
        final gunPrefix = '$_gunCachePrefix${kullaniciId}_';
        final silinecekler = prefs
            .getKeys()
            .where((k) => k.startsWith(gunPrefix))
            .toList();
        for (final anahtar in silinecekler) {
          await prefs.remove(anahtar);
        }
        if (kuyruguDaSil) {
          await prefs.remove(outboxAnahtari(kullaniciId));
        }
      }
      await _eskiAnahtarlariTemizle(prefs);
    } catch (e) {
      debugPrint('[BeslenmeYerelDepo.kullaniciVerileriniTemizle] $e');
    }
  }

  /// Çevrimdışı eklenen öğün için negatif geçici kimlik üretir ve kuyruğa ekler.
  Future<int> ogunEkleKuyrugaAl(
    int kullaniciId, {
    required String tarih,
    required String ogunTipi,
    int? besinId,
    String? besinIsim,
    required double miktar,
    int kalori = 0,
    double protein = 0,
    double karbonhidrat = 0,
    double yag = 0,
    int? porsiyonId,
  }) async {
    _kullaniciIdDogrula(kullaniciId);
    final prefs = await _prefs();
    final siradaki = (prefs.getInt(_geciciIdSayacKey) ?? 0) + 1;
    await prefs.setInt(_geciciIdSayacKey, siradaki);
    final geciciId = -siradaki;

    final kuyruk = await _kuyruguOku(kullaniciId);
    kuyruk.add({
      'tur': 'ogun_ekle',
      'gecici_id': geciciId,
      'tarih': tarih,
      'ogun_tipi': ogunTipi,
      'besin_id': ?besinId,
      'besin_isim': ?besinIsim,
      'miktar': miktar,
      'kalori': kalori,
      'protein': protein,
      'karbonhidrat': karbonhidrat,
      'yag': yag,
      'porsiyon_id': ?porsiyonId,
    });
    await _kuyruguYaz(kullaniciId, kuyruk);
    return geciciId;
  }

  /// Çevrimdışı öğün güncellemesini kuyruğa alır (veya bekleyen eklemeyi birleştirir).
  Future<void> ogunGuncelleKuyrugaAl(
    int kullaniciId, {
    required int id,
    required String tarih,
    required double miktar,
    int? kalori,
    double? protein,
    double? karbonhidrat,
    double? yag,
    int? porsiyonId,
  }) async {
    _kullaniciIdDogrula(kullaniciId);
    final kuyruk = await _kuyruguOku(kullaniciId);
    if (id < 0) {
      for (final islem in kuyruk) {
        if (islem['tur'] == 'ogun_ekle' && islem['gecici_id'] == id) {
          islem['miktar'] = miktar;
          if (kalori != null) islem['kalori'] = kalori;
          if (protein != null) islem['protein'] = protein;
          if (karbonhidrat != null) islem['karbonhidrat'] = karbonhidrat;
          if (yag != null) islem['yag'] = yag;
          if (porsiyonId != null) {
            islem['porsiyon_id'] = porsiyonId;
          } else {
            islem.remove('porsiyon_id');
          }
          await _kuyruguYaz(kullaniciId, kuyruk);
          return;
        }
      }
      return;
    }

    kuyruk.removeWhere(
      (islem) => islem['tur'] == 'ogun_guncelle' && islem['id'] == id,
    );
    kuyruk.add({
      'tur': 'ogun_guncelle',
      'id': id,
      'tarih': tarih,
      'miktar': miktar,
      'kalori': ?kalori,
      'protein': ?protein,
      'karbonhidrat': ?karbonhidrat,
      'yag': ?yag,
      'porsiyon_id': ?porsiyonId,
    });
    await _kuyruguYaz(kullaniciId, kuyruk);
  }

  /// Çevrimdışı öğün silme işlemini kuyruğa alır.
  ///
  /// Henüz sunucuya gitmemiş (`id < 0`) bir öğün silinirse kuyruktaki
  /// `ogun_ekle` kaydı doğrudan düşürülür (gereksiz ağ trafiği önlenir).
  Future<void> ogunSilKuyrugaAl(
    int kullaniciId, {
    required int id,
    required String tarih,
  }) async {
    _kullaniciIdDogrula(kullaniciId);
    final kuyruk = await _kuyruguOku(kullaniciId);
    if (id < 0) {
      kuyruk.removeWhere(
        (islem) => islem['tur'] == 'ogun_ekle' && islem['gecici_id'] == id,
      );
      await _kuyruguYaz(kullaniciId, kuyruk);
      return;
    }

    kuyruk.removeWhere(
      (islem) => islem['tur'] == 'ogun_guncelle' && islem['id'] == id,
    );
    final zatenSilinecek = kuyruk.any(
      (islem) => islem['tur'] == 'ogun_sil' && islem['id'] == id,
    );
    if (!zatenSilinecek) {
      kuyruk.add({'tur': 'ogun_sil', 'id': id, 'tarih': tarih});
    }
    await _kuyruguYaz(kullaniciId, kuyruk);
  }

  /// Çevrimdışı su ekleme işlemini kuyruğa alır (ardışık aynı gün su eklemelerini birleştirir).
  Future<void> suEkleKuyrugaAl(
    int kullaniciId, {
    required String tarih,
    required int miktarMl,
  }) async {
    _kullaniciIdDogrula(kullaniciId);
    final kuyruk = await _kuyruguOku(kullaniciId);
    if (kuyruk.isNotEmpty) {
      final son = kuyruk.last;
      if (son['tur'] == 'su_ekle' && son['tarih'] == tarih) {
        final mevcut = (son['miktar_ml'] as num?)?.toInt() ?? 0;
        son['miktar_ml'] = mevcut + miktarMl;
        await _kuyruguYaz(kullaniciId, kuyruk);
        return;
      }
    }
    kuyruk.add({'tur': 'su_ekle', 'tarih': tarih, 'miktar_ml': miktarMl});
    await _kuyruguYaz(kullaniciId, kuyruk);
  }

  /// Kullanıcının kuyrukta bekleyen işlemlerini sırayla sunucuya gönderir.
  ///
  /// Geçici bir hata (ağ, 401, 429, 5xx ...) alınırsa durur ve kalan işlemleri
  /// kuyrukta korur. Yalnızca sunucunun kalıcı olarak reddettiği (400/404 vb.)
  /// bozuk işlemler kuyruğu tıkamaması için düşürülür; bkz. [kaliciHataMi].
  ///
  /// [devamEtsinMi] her işlemden ÖNCE çağrılır; `false` dönerse (ör. kuyruk
  /// sahibi çıkış yaptıysa veya oturumdaki kullanıcı değiştiyse) boşaltma
  /// derhal durur. Böylece A'nın kuyruğu, A çıkış yapıp B giriş yaptıktan
  /// sonra B'nin token'ıyla gönderilemez.
  Future<int> kuyruguBosalt(
    int kullaniciId,
    ApiServisi api, {
    bool Function()? devamEtsinMi,
  }) async {
    if (kullaniciId <= 0) return 0;
    final mevcutUcus = _bosaltmaUcuslari[kullaniciId];
    if (mevcutUcus != null) {
      await mevcutUcus;
      return bekleyenSayisi(kullaniciId);
    }
    final ucus = _kuyruguBosaltIc(kullaniciId, api, devamEtsinMi);
    _bosaltmaUcuslari[kullaniciId] = ucus;
    try {
      await ucus;
    } finally {
      _bosaltmaUcuslari.remove(kullaniciId);
    }
    return bekleyenSayisi(kullaniciId);
  }

  Future<void> _kuyruguBosaltIc(
    int kullaniciId,
    ApiServisi api,
    bool Function()? devamEtsinMi,
  ) async {
    final kuyruk = await _kuyruguOku(kullaniciId);
    if (kuyruk.isEmpty) return;

    while (kuyruk.isNotEmpty) {
      if (devamEtsinMi != null && !devamEtsinMi()) {
        // Kuyruk sahibi artık aktif oturum değil; başka token ile gönderme.
        break;
      }
      final islem = kuyruk.first;
      try {
        await _islemiCalistir(kullaniciId, api, islem);
        kuyruk.removeAt(0);
        await _kuyruguYaz(kullaniciId, kuyruk);
      } catch (e) {
        if (!kaliciHataMi(e)) {
          // Geçici hata (ağ yok, oturum süresi dolmuş, hız sınırı, sunucu
          // arızası veya tanınmayan hata): kalanları koru ve çık.
          debugPrint('[BeslenmeYerelDepo] Geçici hata, kuyruk korunuyor: $e');
          break;
        }
        // Kalıcı sunucu/validasyon hatası: kuyruğu sonsuza dek tıkamasın.
        debugPrint('[BeslenmeYerelDepo] Kalıcı hata nedeniyle işlem atlandı: $e');
        kuyruk.removeAt(0);
        await _kuyruguYaz(kullaniciId, kuyruk);
      }
    }
  }

  Future<void> _islemiCalistir(
    int kullaniciId,
    ApiServisi api,
    Map<String, dynamic> islem,
  ) async {
    final tur = islem['tur']?.toString();
    switch (tur) {
      case 'ogun_ekle':
        await api.ogunEkle(
          tarih: (islem['tarih'] ?? '').toString(),
          ogunTipi: (islem['ogun_tipi'] ?? 'sabah').toString(),
          besinId: (islem['besin_id'] as num?)?.toInt(),
          besinIsim: islem['besin_isim']?.toString(),
          miktar: (islem['miktar'] as num?)?.toDouble() ?? 100,
          kalori: (islem['kalori'] as num?)?.toInt() ?? 0,
          protein: (islem['protein'] as num?)?.toDouble() ?? 0,
          karbonhidrat: (islem['karbonhidrat'] as num?)?.toDouble() ?? 0,
          yag: (islem['yag'] as num?)?.toDouble() ?? 0,
          porsiyonId: (islem['porsiyon_id'] as num?)?.toInt(),
        );
        break;
      case 'ogun_guncelle':
        await api.ogunGuncelle(
          id: (islem['id'] as num).toInt(),
          miktar: (islem['miktar'] as num).toDouble(),
          kalori: (islem['kalori'] as num?)?.toInt(),
          protein: (islem['protein'] as num?)?.toDouble(),
          karbonhidrat: (islem['karbonhidrat'] as num?)?.toDouble(),
          yag: (islem['yag'] as num?)?.toDouble(),
          porsiyonId: (islem['porsiyon_id'] as num?)?.toInt(),
        );
        break;
      case 'ogun_sil':
        await api.ogunSil((islem['id'] as num).toInt());
        break;
      case 'su_ekle':
        final guncel = await api.suEkle(
          tarih: (islem['tarih'] ?? '').toString(),
          miktarMl: (islem['miktar_ml'] as num).toInt(),
        );
        await gunKaydet(kullaniciId, guncel);
        break;
    }
  }

  Future<List<Map<String, dynamic>>> _kuyruguOku(int kullaniciId) async {
    try {
      final prefs = await _prefs();
      final raw = prefs.getString(outboxAnahtari(kullaniciId));
      if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (e) {
      debugPrint('[BeslenmeYerelDepo._kuyruguOku] $e');
    }
    return <Map<String, dynamic>>[];
  }

  Future<void> _kuyruguYaz(
    int kullaniciId,
    List<Map<String, dynamic>> kuyruk,
  ) async {
    try {
      final prefs = await _prefs();
      final anahtar = outboxAnahtari(kullaniciId);
      if (kuyruk.isEmpty) {
        await prefs.remove(anahtar);
      } else {
        await prefs.setString(anahtar, jsonEncode(kuyruk));
      }
    } catch (e) {
      debugPrint('[BeslenmeYerelDepo._kuyruguYaz] $e');
    }
  }
}
