import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/icerik_model.dart';
import 'models/kategori_model.dart';

class LocalDatabaseService {
  // Profil cache'i ApiService._writeCachedProfile (FlutterSecureStorage)
  // tarafindan yapiliyor; bu sinifin _profilKey/_profilTsKey + cacheProfil
  // /getCachedProfilJson uyeleri hicbir yerden cagrilmiyordu (dead code),
  // Antigravity #8 — silindi.
  static const String _kategoriKey = 'cached_kategoriler';
  static const String _icerikKey = 'cached_icerikler';
  static const String _icerikTsKey = 'cached_icerikler_ts';
  static const Duration _maxAge = Duration(hours: 1);

  // ---------- Kategoriler ----------

  static Future<void> cacheKategoriler(List<KategoriModel> list) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      list.map((e) => {'id': e.id, 'isim': e.isim}).toList(),
    );
    await prefs.setString(_kategoriKey, encoded);
  }

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

  static Future<void> cacheIcerikler(List<IcerikModel> list) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(list.map(_icerikToJson).toList());
    await prefs.setString(_icerikKey, encoded);
    await prefs.setInt(_icerikTsKey, DateTime.now().millisecondsSinceEpoch);
  }

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

  static Future<bool> isIcerikCacheStale() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_icerikTsKey);
    if (ts == null) return true;
    return DateTime.now().millisecondsSinceEpoch - ts > _maxAge.inMilliseconds;
  }

  // ---------- Serialize yardımcıları ----------

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
