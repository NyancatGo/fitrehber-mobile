// ---------------------------------------------------------------------------
// YEREL ÖNBELLEK (CACHE) SERVİSİ
// ---------------------------------------------------------------------------
// Kategori ve içerik listelerini cihazın yerel deposunda (SharedPreferences)
// saklar. Amaç: uygulama açılır açılmaz internet beklemeden son verileri
// göstermek ve internet yokken bile temel içeriğin görünür kalmasını sağlamak.
//
// Önbellek 1 saat sonra "bayat" sayılır; bu süre dolunca arka planda taze
// veri çekilir.
// ---------------------------------------------------------------------------

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/icerik_model.dart';
import 'models/kategori_model.dart';

/// İçerik ve kategori listelerini yerel olarak önbelleğe alan servis.
class YerelVeritabaniServisi {
  /// Önbelleğe alınan kategori listesinin depo anahtarı.
  static const String _kategoriKey = 'cached_kategoriler';

  /// Önbelleğe alınan içerik listesinin depo anahtarı.
  static const String _icerikKey = 'cached_icerikler';

  /// İçerik önbelleğinin en son ne zaman yazıldığını tutan depo anahtarı.
  static const String _icerikTsKey = 'cached_icerikler_ts';

  /// Önbelleğin "taze" sayıldığı süre; bu süre dolunca veri bayatlamış olur.
  static const Duration _maxAge = Duration(hours: 1);

  // ---------- Kategoriler ----------

  /// Kategori listesini yerel önbelleğe yazar.
  static Future<void> cacheKategoriler(List<KategoriModel> list) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      list.map((e) => {'id': e.id, 'isim': e.isim}).toList(),
    );
    await prefs.setString(_kategoriKey, encoded);
  }

  /// Önbellekteki kategori listesini okur; yoksa boş liste döner.
  static Future<List<KategoriModel>> getCachedKategoriler() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kategoriKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => KategoriModel.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // ---------- İçerikler ----------

  /// İçerik listesini, yazım zaman damgasıyla birlikte yerel önbelleğe yazar.
  static Future<void> cacheIcerikler(List<IcerikModel> list) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(list.map(_icerikToJson).toList());
    await prefs.setString(_icerikKey, encoded);
    await prefs.setInt(_icerikTsKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Önbellekteki içerik listesini okur; yoksa boş liste döner.
  static Future<List<IcerikModel>> getCachedIcerikler() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_icerikKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => IcerikModel.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  /// İçerik önbelleğinin bayatlayıp bayatlamadığını (1 saatten eski) bildirir.
  static Future<bool> isIcerikCacheStale() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_icerikTsKey);
    if (ts == null) return true;
    return DateTime.now().millisecondsSinceEpoch - ts > _maxAge.inMilliseconds;
  }

  // ---------- Serialize yardımcıları ----------

  /// Bir `IcerikModel`i, önbelleğe yazılabilecek JSON haritasına dönüştürür.
  static Map<String, dynamic> _icerikToJson(IcerikModel m) {
    return {
      'id': m.id,
      'baslik': m.baslik,
      'resim': m.resim,
      'resim_url': m.resimUrl,
      'tur': m.tur,
      'tarih': m.tarih,
      'yazar': m.yazar,
      'kategori': m.kategori,
      'yazi': m.yazi,
      'yazi_temiz': m.rawYaziTemiz,
      'yorum_sayisi': m.yorumSayisi,
      'begeni_sayisi': m.begeniSayisi,
      'begendim': m.begendim,
      'kaydedildi': m.kaydedildi,
      'ozet': m.ozet,
      'okuma_suresi': m.okumaSuresi,
    };
  }
}
