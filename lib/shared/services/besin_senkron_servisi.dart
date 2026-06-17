// ---------------------------------------------------------------------------
// BESİN SENKRON SERVİSİ
// ---------------------------------------------------------------------------
// Sunucudaki besin veritabanını (WEB'in sahibi olduğu tek kaynak) cihazın yerel
// önbelleğine indirir. Böylece arama OFFLINE ve anlık kalırken, eklenen besinler
// gerçek `besin_id` taşır (web ile birebir tutarlı, "doğrulanmış" kayıt).
//
// Akış:
//   1) İlk senkron (since yok)  -> tüm besinler sayfa sayfa indirilir.
//   2) Sonraki senkronlar       -> yalnız `updated_at > son_server_time` olanlar.
//   3) Sonuç SharedPreferences'a yazılır + YerelBesinVeritabani tazelenir.
// Ağ hatasında sessizce atlanır; mevcut önbellek korunur (uygulama çökmez).
// ---------------------------------------------------------------------------

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_servisi.dart';
import 'yerel_besin_veritabani.dart';

typedef BesinSenkronSayfasiGetir =
    Future<Map<String, dynamic>> Function({
      String? since,
      int offset,
      int limit,
    });

class BesinSenkronServisi {
  BesinSenkronServisi._({BesinSenkronSayfasiGetir? sayfaGetir})
    : _sayfaGetir = sayfaGetir ?? ApiServisi().besinSenkronSayfasi;

  @visibleForTesting
  BesinSenkronServisi.test({required BesinSenkronSayfasiGetir sayfaGetir})
    : _sayfaGetir = sayfaGetir;

  static final BesinSenkronServisi instance = BesinSenkronServisi._();

  final BesinSenkronSayfasiGetir _sayfaGetir;
  bool _calisiyor = false;

  /// Bu süreden daha yeni bir senkron varsa (zorla=false iken) tekrar denenmez.
  static const Duration _minAralik = Duration(hours: 6);
  static const int _sayfaBoyu = 1000;
  static const int _maxSayfa = 50; // güvenlik: sonsuz döngü koruması

  /// Gerekiyorsa besin veritabanını senkronlar. Fire-and-forget çağrılabilir;
  /// hata fırlatmaz. [zorla] true ise throttle atlanır.
  Future<void> senkronEt({bool zorla = false}) async {
    if (_calisiyor) return;
    _calisiyor = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!zorla && !_zamaniGeldi(prefs)) return;

      final lastSync = prefs.getString(YerelBesinVeritabani.lastSyncKey);
      final mevcutCache = prefs.getString(YerelBesinVeritabani.cacheKey) ?? '';
      final delta =
          mevcutCache.isNotEmpty && lastSync != null && lastSync.isNotEmpty;

      // Delta ise mevcut önbelleği id->kayıt olarak yükle; tam senkronda sıfırdan.
      final Map<int, Map<String, dynamic>> birikim = {};
      if (delta) {
        for (final f in _cacheMaplari(mevcutCache)) {
          final id = (f['id'] as num?)?.toInt();
          if (id != null) birikim[id] = f;
        }
      }

      String? serverTime;
      var offset = 0;
      var degisti = false;
      for (var sayfa = 0; sayfa < _maxSayfa; sayfa++) {
        final res = await _sayfaGetir(
          since: delta ? lastSync : null,
          offset: offset,
          limit: _sayfaBoyu,
        );
        // Bir senkron turunun İLK sayfasındaki server_time'ı bir sonraki
        // ?since= olarak saklarız (sayfalar arası değişiklikler bir sonraki
        // turda yakalanır; id-bazlı upsert tekrarları zararsız kılar).
        serverTime ??= res['serverTime'] as String?;
        final foods = (res['foods'] as List).cast<Map<String, dynamic>>();
        for (final f in foods) {
          final id = (f['id'] as num?)?.toInt();
          if (id != null) {
            birikim[id] = f;
            degisti = true;
          }
        }
        offset += foods.length;
        if (res['hasMore'] != true || foods.isEmpty) break;
      }

      // Tam senkronda her zaman yaz; delta'da yalnız değişiklik geldiyse.
      if (!delta || degisti) {
        final liste = birikim.values.toList();
        await prefs.setString(YerelBesinVeritabani.cacheKey, jsonEncode(liste));
        YerelBesinVeritabani.instance.cachetenYukle(liste);
      }
      if (serverTime != null && serverTime.isNotEmpty) {
        await prefs.setString(YerelBesinVeritabani.lastSyncKey, serverTime);
      }
      await prefs.setString(
        YerelBesinVeritabani.lastSyncAtKey,
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      debugPrint('[BesinSenkron] atlandı (önbellek korunuyor): $e');
    } finally {
      _calisiyor = false;
    }
  }

  bool _zamaniGeldi(SharedPreferences prefs) {
    final at = prefs.getString(YerelBesinVeritabani.lastSyncAtKey);
    if (at == null) return true;
    final t = DateTime.tryParse(at);
    if (t == null) return true;
    return DateTime.now().difference(t) >= _minAralik;
  }

  List<Map<String, dynamic>> _cacheMaplari(String raw) {
    try {
      return (json.decode(raw) as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
