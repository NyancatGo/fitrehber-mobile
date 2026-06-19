// ---------------------------------------------------------------------------
// BESLENME DURUM YÖNETİMİ (RIVERPOD)
// ---------------------------------------------------------------------------
// Beslenme ekranının günlük verisini ve hedeflerini tutar. Öğün/su işlemleri
// API'ye gider; profil değişince kalori, makro ve su hedefleri yeniden
// hesaplanır.
// ---------------------------------------------------------------------------

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/api_servisi.dart';
import '../../../shared/models/beslenme_model.dart';
import '../../../shared/oturum_denetleyici.dart';
import '../../../shared/services/besin_senkron_servisi.dart';
import '../../../shared/utils/beslenme_hesaplayici.dart';

/// Beslenme ekranının anlık durumunu temsil eden değişmez veri sınıfı.
class BeslenmeDurumu {
  /// Veri yükleme işlemi sürüyor mu?
  final bool isLoading;

  /// Son işlemde oluşan hata mesajı (yoksa `null`).
  final String? hata;

  /// Seçili güne ait beslenme verisi (henüz yüklenmediyse `null`).
  final GunlukBeslenmeModel? veri;

  /// Şu an görüntülenen tarih (`YYYY-AA-GG`).
  final String seciliTarih;

  /// Kullanıcının profiline göre hesaplanan günlük kalori/makro/su hedefleri.
  final BeslenmeHedefleri hedefler;

  BeslenmeDurumu({
    this.isLoading = false,
    this.hata,
    this.veri,
    required this.seciliTarih,
    this.hedefler = BeslenmeHedefleri.defaults,
  });

  BeslenmeDurumu copyWith({
    bool? isLoading,
    String? hata,
    GunlukBeslenmeModel? veri,
    String? seciliTarih,
    BeslenmeHedefleri? hedefler,
    bool clearHata = false,
    bool clearVeri = false,
  }) {
    return BeslenmeDurumu(
      isLoading: isLoading ?? this.isLoading,
      hata: clearHata ? null : (hata ?? this.hata),
      veri: clearVeri ? null : (veri ?? this.veri),
      seciliTarih: seciliTarih ?? this.seciliTarih,
      hedefler: hedefler ?? this.hedefler,
    );
  }
}

/// Beslenme verisinin yüklenmesini ve değiştirilmesini yöneten kontrolcü.
class BeslenmeDenetleyici extends StateNotifier<BeslenmeDurumu> {
  final ApiServisi _api = ApiServisi();
  final Ref _ref;

  BeslenmeDenetleyici(this._ref)
    : super(BeslenmeDurumu(seciliTarih: _bugunStr())) {
    _hesaplaHedefler();
    load(_bugunStr());
    // Besin veritabanını arka planda sunucuyla senkronla (6 saatte bir, ağ
    // hatasında sessiz). Böylece offline arama tazelenir ve eklenen besinler
    // gerçek besin_id taşır (web ile tutarlı). Fire-and-forget.
    BesinSenkronServisi.instance.senkronEt();
    // Profil hedef hesabının girdisidir; boy/kilo/hedef/su değişirse ekran
    // yeniden açılmadan hedefler güncellenir.
    _ref.listen<OturumDurumu>(oturumDenetleyiciProvider, (prev, next) {
      final p = prev?.profile;
      final n = next.profile;
      final degisti =
          p?.customWaterGoalMl != n?.customWaterGoalMl ||
          p?.weight != n?.weight ||
          p?.height != n?.height ||
          p?.goal != n?.goal ||
          p?.gender != n?.gender ||
          p?.birthDate != n?.birthDate;
      if (degisti) _hesaplaHedefler();
    });
  }

  /// Profil verilerinden dinamik hedefleri hesaplar.
  void _hesaplaHedefler() {
    final session = _ref.read(oturumDenetleyiciProvider);
    final profil = session.profile;
    final hedefler = BeslenmeHesaplayici.calculate(profil);
    state = state.copyWith(hedefler: hedefler);
  }

  /// Verilen tarihin beslenme verisini sunucudan yükler.
  Future<void> load(String tarih) async {
    final normalTarih = normalizeBeslenmeTarih(tarih);
    state = state.copyWith(
      isLoading: true,
      seciliTarih: normalTarih,
      clearHata: true,
    );

    // Her yükleme sırasında hedefleri de güncelle (profil değişmiş olabilir).
    _hesaplaHedefler();

    try {
      final veri = await _api.beslenmeSuyuGetir(normalTarih);
      state = state.copyWith(isLoading: false, veri: veri);
    } catch (e) {
      debugPrint('[BeslenmeDenetleyici.load] $e');
      // Veri yoksa UI'ı boş modelle ayakta tut, ama hatayı kullanıcıya göster.
      state = state.copyWith(
        isLoading: false,
        veri: GunlukBeslenmeModel(tarih: normalTarih),
        hata: _mesaj(e),
      );
    }
  }

  /// Seçili güne [ml] kadar su ekler. Başarılıysa `true` döner.
  Future<bool> suEkle(int ml) async {
    final onceki = state.veri;
    final tarih = state.seciliTarih;
    if (onceki != null) {
      // Optimistic update: kullanıcı su barını hemen görür. Sunucu yanıtı
      // geldikten sonra kanonik değerle düzeltilir.
      final yeni = (onceki.suMl + ml).clamp(0, 100000);
      state = state.copyWith(veri: onceki.copyWith(suMl: yeni));
    }
    try {
      // API zaten güncel günlük modeli döndürür; ekstra GET atmak hem yavaş hem
      // gereksizdir, çünkü su ekleme profil hedeflerini değiştirmez.
      final guncel = await _api.suEkle(tarih: tarih, miktarMl: ml);
      if (mounted) {
        state = state.copyWith(veri: guncel);
      }
      return true;
    } catch (e) {
      debugPrint('[BeslenmeDenetleyici.suEkle] $e');
      if (mounted) {
        state = state.copyWith(isLoading: false, veri: onceki, hata: _mesaj(e));
      }
      return false;
    }
  }

  /// Besin veritabanında metne göre arama yapar.
  Future<List<BesinModel>> besinAra(String query) {
    return _api.besinAra(query);
  }

  /// Offline aramada sonuç azsa kullanıcı ihtiyacını API'ye sessizce bildirir.
  Future<void> besinAramaLoguGonder({
    required String query,
    required int resultCount,
  }) async {
    try {
      await _api.besinAramaLoguGonder(
        query: query,
        resultCount: resultCount,
      );
    } catch (e) {
      debugPrint('[BeslenmeDenetleyici.besinAramaLoguGonder] $e');
    }
  }

  /// Seçili güne, belirtilen öğüne yeni bir besin kaydı ekler.
  Future<bool> ogunEkle({
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
    final tarih = state.seciliTarih;
    state = state.copyWith(isLoading: true, clearHata: true);
    try {
      await _api.ogunEkle(
        tarih: tarih,
        ogunTipi: ogunTipi,
        besinId: besinId,
        besinIsim: besinIsim,
        miktar: miktar,
        kalori: kalori,
        protein: protein,
        karbonhidrat: karbonhidrat,
        yag: yag,
        porsiyonId: porsiyonId,
      );
      await load(tarih);
      return true;
    } catch (e) {
      debugPrint('[BeslenmeDenetleyici.ogunEkle] $e');
      if (mounted) {
        state = state.copyWith(isLoading: false, hata: _mesaj(e));
      }
      return false;
    }
  }

  /// Mevcut kaydı tek atomic PATCH ile günceller.
  ///
  /// Eski "ekle sonra sil" akışı ağ kesilince çift kayıt bırakabiliyordu.
  /// Mobil sadece miktarı gönderir; doğrulanmış besinde makro hesabı sunucudadır.
  Future<bool> ogunGuncelle({
    required OgunKaydiModel eski,
    required double yeniMiktar,
    int? porsiyonId,
  }) async {
    if (yeniMiktar <= 0) {
      state = state.copyWith(hata: 'Miktar sıfırdan büyük olmalı.');
      return false;
    }
    if (yeniMiktar == eski.miktar && porsiyonId == eski.porsiyon?.id) return true; // Değişiklik yok.

    final tarih = state.seciliTarih;
    state = state.copyWith(isLoading: true, clearHata: true);

    try {
      await _api.ogunGuncelle(
        id: eski.id,
        miktar: yeniMiktar,
        porsiyonId: porsiyonId,
      );
      // Günlük toplamlar sunucuda hesaplandığı için güncel modeli tekrar çek.
      await load(tarih);
      return true;
    } catch (e) {
      debugPrint('[ogunGuncelle] PATCH başarısız: $e');
      if (mounted) {
        state = state.copyWith(isLoading: false, hata: _mesaj(e));
      }
      return false;
    }
  }

  /// Kimliği verilen öğün kaydını siler.
  Future<bool> ogunSil(int id) async {
    final tarih = state.seciliTarih;
    state = state.copyWith(isLoading: true, clearHata: true);
    try {
      await _api.ogunSil(id);
      await load(tarih);
      return true;
    } catch (e) {
      debugPrint('[BeslenmeDenetleyici.ogunSil] $e');
      if (mounted) {
        state = state.copyWith(isLoading: false, hata: _mesaj(e));
      }
      return false;
    }
  }

  /// Bir önceki günün öğünlerini seçili güne kopyalar. Başarılıysa true,
  /// hata (kaynak boş / hedef dolu / gelecek) durumunda hata mesajı state'e yazılır.
  Future<bool> ogunleriKopyala() async {
    final tarih = state.seciliTarih;
    state = state.copyWith(isLoading: true, clearHata: true);
    try {
      await _api.ogunleriKopyala(tarih);
      await load(tarih);
      return true;
    } catch (e) {
      debugPrint('[BeslenmeDenetleyici.ogunleriKopyala] $e');
      if (mounted) {
        state = state.copyWith(isLoading: false, hata: _mesaj(e));
      }
      return false;
    }
  }

  /// Son kullanılan besinleri sunucudan getirir (hızlı yeniden ekleme için).
  Future<List<Map<String, dynamic>>> sonKullanilanBesinler() async {
    try {
      return await _api.sonKullanilanBesinler();
    } catch (e) {
      debugPrint('[BeslenmeDenetleyici.sonKullanilanBesinler] $e');
      return const [];
    }
  }

  String _mesaj(Object e) {
    // ApiServisi genelde anlaşılır bir String fırlatır; ama
    // ağ/timeout gibi durumlarda Exception/DioException gelebilir.
    final raw = e is String ? e : e.toString();
    return raw.replaceFirst(RegExp(r'^Exception: '), '');
  }

  static String _bugunStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

/// Beslenme ekranının durumunu sağlayan provider.
@visibleForTesting
String normalizeBeslenmeTarih(String tarih) {
  final now = DateTime.now();
  final bugun = DateTime(now.year, now.month, now.day);
  try {
    final parsed = DateTime.parse(tarih);
    final gun = DateTime(parsed.year, parsed.month, parsed.day);
    if (gun.isAfter(bugun)) return BeslenmeDenetleyici._bugunStr();
    return '${gun.year}-${gun.month.toString().padLeft(2, '0')}-${gun.day.toString().padLeft(2, '0')}';
  } catch (_) {
    return BeslenmeDenetleyici._bugunStr();
  }
}

final beslenmeProvider =
    StateNotifierProvider<BeslenmeDenetleyici, BeslenmeDurumu>((ref) {
      return BeslenmeDenetleyici(ref);
    });
