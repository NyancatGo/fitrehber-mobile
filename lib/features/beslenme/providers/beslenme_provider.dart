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
import '../../../shared/services/beslenme_yerel_depo.dart';
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

  /// Şu an görüntülenen veri çevrimdışı yerel önbellekten mi geliyor?
  final bool cevrimdisiMi;

  /// Çevrimdışı yazma kuyruğunda (outbox) sunucuya gönderilmeyi bekleyen işlem sayısı.
  final int bekleyenIslemSayisi;

  BeslenmeDurumu({
    this.isLoading = false,
    this.hata,
    this.veri,
    required this.seciliTarih,
    this.hedefler = BeslenmeHedefleri.defaults,
    this.cevrimdisiMi = false,
    this.bekleyenIslemSayisi = 0,
  });

  BeslenmeDurumu copyWith({
    bool? isLoading,
    String? hata,
    GunlukBeslenmeModel? veri,
    String? seciliTarih,
    BeslenmeHedefleri? hedefler,
    bool? cevrimdisiMi,
    int? bekleyenIslemSayisi,
    bool clearHata = false,
    bool clearVeri = false,
  }) {
    return BeslenmeDurumu(
      isLoading: isLoading ?? this.isLoading,
      hata: clearHata ? null : (hata ?? this.hata),
      veri: clearVeri ? null : (veri ?? this.veri),
      seciliTarih: seciliTarih ?? this.seciliTarih,
      hedefler: hedefler ?? this.hedefler,
      cevrimdisiMi: cevrimdisiMi ?? this.cevrimdisiMi,
      bekleyenIslemSayisi: bekleyenIslemSayisi ?? this.bekleyenIslemSayisi,
    );
  }
}

/// Beslenme verisinin yüklenmesini ve değiştirilmesini yöneten kontrolcü.
///
/// Her denetleyici örneği TEK bir kullanıcıya bağlıdır ([_kullaniciId]
/// oluşturulurken sabitlenir). Oturumdaki kullanıcı değiştiğinde provider
/// yeniden oluşturulur; böylece bir kullanıcının bellek içi durumu, yerel
/// önbelleği veya çevrimdışı kuyruğu başka bir hesaba asla taşınmaz.
class BeslenmeDenetleyici extends StateNotifier<BeslenmeDurumu> {
  final ApiServisi _api;
  final BeslenmeYerelDepo _depo;
  final Ref? _ref;

  /// Bu denetleyicinin ait olduğu kullanıcı (geçersizse `null`: yerel
  /// önbellek ve çevrimdışı kuyruk devre dışı kalır).
  final int? _kullaniciId;

  BeslenmeDenetleyici(
    Ref? ref, {
    ApiServisi? api,
    BeslenmeYerelDepo? depo,
    int? kullaniciId,
    bool baslangicYukle = true,
  }) : _ref = ref,
       _api = api ?? (ref != null ? ref.read(apiServisiProvider) : ApiServisi.instance),
       _depo = depo ?? BeslenmeYerelDepo.instance,
       _kullaniciId = _gecerliKullaniciId(
         kullaniciId ?? ref?.read(oturumDenetleyiciProvider).profile?.id,
       ),
       super(BeslenmeDurumu(seciliTarih: _bugunStr())) {
    if (baslangicYukle && _kullaniciId != null) {
      _hesaplaHedefler();
      load(_bugunStr());
      // Besin veritabanını arka planda sunucuyla senkronla (6 saatte bir, ağ
      // hatasında sessiz). Böylece offline arama tazelenir ve eklenen besinler
      // gerçek besin_id taşır (web ile tutarlı). Fire-and-forget.
      BesinSenkronServisi.instance.senkronEt();
    }
    // Profil hedef hesabının girdisidir; boy/kilo/hedef/su değişirse ekran
    // yeniden açılmadan hedefler güncellenir.
    _ref?.listen<OturumDurumu>(oturumDenetleyiciProvider, (prev, next) {
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
    final ref = _ref;
    if (ref == null) return;
    final session = ref.read(oturumDenetleyiciProvider);
    final profil = session.profile;
    final hedefler = BeslenmeHesaplayici.calculate(profil);
    state = state.copyWith(hedefler: hedefler);
  }

  static int? _gecerliKullaniciId(int? id) =>
      (id != null && id > 0) ? id : null;

  /// Bu denetleyicinin sahibi hâlâ oturumdaki kullanıcı mı?
  ///
  /// Çıkış/hesap değişimi ile provider'ın yeniden oluşturulması arasındaki
  /// kısa pencerede bile eski kullanıcının kuyruğunun yeni token'la
  /// gönderilmesini engeller.
  bool _sahipHalaAktifMi() {
    if (!mounted || _kullaniciId == null) return false;
    final ref = _ref;
    if (ref == null) return true;
    try {
      return ref.read(oturumDenetleyiciProvider).profile?.id == _kullaniciId;
    } catch (_) {
      return false;
    }
  }

  /// Kullanıcının outbox kuyruğunu (sahiplik denetimiyle) boşaltmayı dener.
  Future<void> _kuyruguBosalt() async {
    final uid = _kullaniciId;
    if (uid == null) return;
    await _depo.kuyruguBosalt(uid, _api, devamEtsinMi: _sahipHalaAktifMi);
  }

  Future<int> _bekleyenSayisi() async {
    final uid = _kullaniciId;
    if (uid == null) return 0;
    return _depo.bekleyenSayisi(uid);
  }

  Future<GunlukBeslenmeModel?> _yereldenOku(String tarih) async {
    final uid = _kullaniciId;
    if (uid == null) return null;
    return _depo.gunOku(uid, tarih);
  }

  Future<void> _yereleYaz(GunlukBeslenmeModel model) async {
    final uid = _kullaniciId;
    if (uid == null) return;
    await _depo.gunKaydet(uid, model);
  }

  /// Çevrimdışı kuyruğa alma mümkünse (geçerli kullanıcı + ağ hatası) `true`.
  bool _kuyrugaAlinabilirMi(Object e) =>
      _kullaniciId != null && BeslenmeYerelDepo.agHatasiMi(e);

  /// Bekleyen çevrimdışı işlemleri sunucuya iletmeyi dener (ör. AI asistanı
  /// güncel veriyi okumadan önce). Hata fırlatmaz; kalan işlem sayısını döner.
  Future<int> bekleyenleriSenkronla() async {
    try {
      await _kuyruguBosalt();
    } catch (e) {
      debugPrint('[BeslenmeDenetleyici.bekleyenleriSenkronla] $e');
    }
    final kalan = await _bekleyenSayisi();
    if (mounted && kalan != state.bekleyenIslemSayisi) {
      state = state.copyWith(bekleyenIslemSayisi: kalan);
    }
    return kalan;
  }

  /// Verilen tarihin beslenme verisini sunucudan (veya çevrimdışı önbellekten) yükler.
  Future<void> load(String tarih) async {
    final normalTarih = normalizeBeslenmeTarih(tarih);
    final tarihDegisti = state.seciliTarih != normalTarih;
    state = state.copyWith(
      isLoading: true,
      seciliTarih: normalTarih,
      clearHata: true,
    );

    // Her yükleme sırasında hedefleri de güncelle (profil değişmiş olabilir).
    _hesaplaHedefler();

    // 1) Yerel önbellekte bu günün verisi varsa hemen göster (hızlı açılış + offline).
    final yerelVeri = await _yereldenOku(normalTarih);
    if (mounted && yerelVeri != null && (state.veri == null || tarihDegisti)) {
      state = state.copyWith(veri: yerelVeri);
    }

    try {
      // 2) Önce bekleyen çevrimdışı yazma kuyruğu (outbox) varsa boşaltmayı dene.
      await _kuyruguBosalt();
      final kalanSayisi = await _bekleyenSayisi();

      // 3) Sunucudan güncel veriyi çek ve yerel önbelleği güncelle.
      final veri = await _api.beslenmeSuyuGetir(normalTarih);
      await _yereleYaz(veri);
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          veri: veri,
          cevrimdisiMi: false,
          bekleyenIslemSayisi: kalanSayisi,
        );
      }
    } catch (e) {
      debugPrint('[BeslenmeDenetleyici.load] $e');
      final bekleyen = await _bekleyenSayisi();
      final yedek = await _yereldenOku(normalTarih);
      final agHatasi = BeslenmeYerelDepo.agHatasiMi(e);
      if (!mounted) return;
      if (agHatasi) {
        state = state.copyWith(
          isLoading: false,
          veri: yedek ?? state.veri ?? GunlukBeslenmeModel(tarih: normalTarih),
          cevrimdisiMi: true,
          bekleyenIslemSayisi: bekleyen,
          clearHata: yedek != null || state.veri != null,
          hata: (yedek == null && state.veri == null) ? _mesaj(e) : null,
        );
      } else {
        // Veri yoksa UI'ı boş modelle ayakta tut, ama hatayı kullanıcıya göster.
        state = state.copyWith(
          isLoading: false,
          veri: yedek ?? GunlukBeslenmeModel(tarih: normalTarih),
          bekleyenIslemSayisi: bekleyen,
          hata: _mesaj(e),
        );
      }
    }
  }

  /// Seçili güne [ml] kadar su ekler. Başarılıysa `true` döner.
  Future<bool> suEkle(int ml) async {
    final onceki = state.veri ?? GunlukBeslenmeModel(tarih: state.seciliTarih);
    final tarih = state.seciliTarih;
    final yeniSu = (onceki.suMl + ml).clamp(0, 100000);
    final iyimserModel = onceki.copyWith(suMl: yeniSu);

    // Optimistic update: kullanıcı su barını hemen görür.
    state = state.copyWith(veri: iyimserModel, clearHata: true);

    try {
      await _kuyruguBosalt();
      final guncel = await _api.suEkle(tarih: tarih, miktarMl: ml);
      await _yereleYaz(guncel);
      final bekleyen = await _bekleyenSayisi();
      if (mounted) {
        state = state.copyWith(
          veri: guncel,
          cevrimdisiMi: false,
          bekleyenIslemSayisi: bekleyen,
        );
      }
      return true;
    } catch (e) {
      debugPrint('[BeslenmeDenetleyici.suEkle] $e');
      if (_kuyrugaAlinabilirMi(e)) {
        await _depo.suEkleKuyrugaAl(_kullaniciId!, tarih: tarih, miktarMl: ml);
        await _yereleYaz(iyimserModel);
        final bekleyen = await _bekleyenSayisi();
        if (mounted) {
          state = state.copyWith(
            isLoading: false,
            veri: iyimserModel,
            cevrimdisiMi: true,
            bekleyenIslemSayisi: bekleyen,
            clearHata: true,
          );
        }
        return true;
      }
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
      await _api.besinAramaLoguGonder(query: query, resultCount: resultCount);
    } catch (e) {
      debugPrint('[BeslenmeDenetleyici.besinAramaLoguGonder] $e');
    }
  }

  Future<bool> besinKatkiGonder({
    required String isim,
    required int kalori100g,
    required double protein100g,
    required double karbonhidrat100g,
    required double yag100g,
  }) async {
    try {
      await _api.besinKatkiGonder(
        isim: isim,
        kalori100g: kalori100g,
        protein100g: protein100g,
        karbonhidrat100g: karbonhidrat100g,
        yag100g: yag100g,
      );
      return true;
    } catch (e) {
      debugPrint('[BeslenmeDenetleyici.besinKatkiGonder] $e');
      if (mounted) {
        state = state.copyWith(hata: _mesaj(e));
      }
      return false;
    }
  }

  Future<Map<String, dynamic>?> besinBarkodSorgula(String barkod) async {
    try {
      return await _api.besinBarkodSorgula(barkod);
    } catch (e) {
      debugPrint('[BeslenmeDenetleyici.besinBarkodSorgula] $e');
      if (mounted) {
        state = state.copyWith(hata: _mesaj(e));
      }
      return null;
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
      await _kuyruguBosalt();
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
      if (_kuyrugaAlinabilirMi(e)) {
        final geciciId = await _depo.ogunEkleKuyrugaAl(
          _kullaniciId!,
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
        final yeniKayit = OgunKaydiModel(
          id: geciciId,
          tarih: tarih,
          ogunTipi: ogunTipi,
          besinId: besinId,
          besinIsim: (besinIsim != null && besinIsim.trim().isNotEmpty)
              ? besinIsim.trim()
              : 'Besin #${besinId ?? 0}',
          miktar: miktar,
          miktarBirimi: porsiyonId != null ? 'porsiyon' : 'g',
          kalori: kalori,
          protein: protein,
          karbonhidrat: karbonhidrat,
          yag: yag,
          porsiyon: porsiyonId != null
              ? BesinPorsiyonModel(
                  id: porsiyonId,
                  isim: 'Porsiyon',
                  gramEsdegeri: 0,
                )
              : null,
        );
        final yeniModel = _yerelOgunEkle(tarih, ogunTipi, yeniKayit);
        await _yereleYaz(yeniModel);
        final bekleyen = await _bekleyenSayisi();
        if (mounted) {
          state = state.copyWith(
            isLoading: false,
            veri: yeniModel,
            cevrimdisiMi: true,
            bekleyenIslemSayisi: bekleyen,
            clearHata: true,
          );
        }
        return true;
      }
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
    if (yeniMiktar == eski.miktar && porsiyonId == eski.porsiyon?.id) {
      return true; // Değişiklik yok.
    }

    final tarih = state.seciliTarih;
    final oran = eski.miktar > 0 ? (yeniMiktar / eski.miktar) : 1.0;
    final yeniKalori = (eski.kalori * oran).round();
    final yeniProtein = double.parse((eski.protein * oran).toStringAsFixed(1));
    final yeniKarbonhidrat = double.parse(
      (eski.karbonhidrat * oran).toStringAsFixed(1),
    );
    final yeniYag = double.parse((eski.yag * oran).toStringAsFixed(1));

    // Henüz sunucuya gitmemiş (çevrimdışı eklenmiş) kayıt güncelleniyorsa:
    if (eski.id < 0) {
      final uid = _kullaniciId;
      if (uid == null) return false;
      await _depo.ogunGuncelleKuyrugaAl(
        uid,
        id: eski.id,
        tarih: tarih,
        miktar: yeniMiktar,
        kalori: yeniKalori,
        protein: yeniProtein,
        karbonhidrat: yeniKarbonhidrat,
        yag: yeniYag,
        porsiyonId: porsiyonId,
      );
      final guncelKayit = eski.copyWith(
        miktar: yeniMiktar,
        kalori: yeniKalori,
        protein: yeniProtein,
        karbonhidrat: yeniKarbonhidrat,
        yag: yeniYag,
      );
      final yeniModel = _yerelOgunGuncelle(tarih, guncelKayit);
      await _yereleYaz(yeniModel);
      final bekleyen = await _bekleyenSayisi();
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          veri: yeniModel,
          bekleyenIslemSayisi: bekleyen,
          clearHata: true,
        );
      }
      return true;
    }

    state = state.copyWith(isLoading: true, clearHata: true);

    try {
      await _kuyruguBosalt();
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
      if (_kuyrugaAlinabilirMi(e)) {
        await _depo.ogunGuncelleKuyrugaAl(
          _kullaniciId!,
          id: eski.id,
          tarih: tarih,
          miktar: yeniMiktar,
          kalori: yeniKalori,
          protein: yeniProtein,
          karbonhidrat: yeniKarbonhidrat,
          yag: yeniYag,
          porsiyonId: porsiyonId,
        );
        final guncelKayit = eski.copyWith(
          miktar: yeniMiktar,
          kalori: yeniKalori,
          protein: yeniProtein,
          karbonhidrat: yeniKarbonhidrat,
          yag: yeniYag,
        );
        final yeniModel = _yerelOgunGuncelle(tarih, guncelKayit);
        await _yereleYaz(yeniModel);
        final bekleyen = await _bekleyenSayisi();
        if (mounted) {
          state = state.copyWith(
            isLoading: false,
            veri: yeniModel,
            cevrimdisiMi: true,
            bekleyenIslemSayisi: bekleyen,
            clearHata: true,
          );
        }
        return true;
      }
      if (mounted) {
        state = state.copyWith(isLoading: false, hata: _mesaj(e));
      }
      return false;
    }
  }

  /// Kimliği verilen öğün kaydını siler.
  Future<bool> ogunSil(int id) async {
    final tarih = state.seciliTarih;
    if (id < 0) {
      final uid = _kullaniciId;
      if (uid == null) return false;
      await _depo.ogunSilKuyrugaAl(uid, id: id, tarih: tarih);
      final yeniModel = _yerelOgunSil(tarih, id);
      await _yereleYaz(yeniModel);
      final bekleyen = await _bekleyenSayisi();
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          veri: yeniModel,
          bekleyenIslemSayisi: bekleyen,
          clearHata: true,
        );
      }
      return true;
    }

    state = state.copyWith(isLoading: true, clearHata: true);
    try {
      await _kuyruguBosalt();
      await _api.ogunSil(id);
      await load(tarih);
      return true;
    } catch (e) {
      debugPrint('[BeslenmeDenetleyici.ogunSil] $e');
      if (_kuyrugaAlinabilirMi(e)) {
        await _depo.ogunSilKuyrugaAl(_kullaniciId!, id: id, tarih: tarih);
        final yeniModel = _yerelOgunSil(tarih, id);
        await _yereleYaz(yeniModel);
        final bekleyen = await _bekleyenSayisi();
        if (mounted) {
          state = state.copyWith(
            isLoading: false,
            veri: yeniModel,
            cevrimdisiMi: true,
            bekleyenIslemSayisi: bekleyen,
            clearHata: true,
          );
        }
        return true;
      }
      if (mounted) {
        state = state.copyWith(isLoading: false, hata: _mesaj(e));
      }
      return false;
    }
  }

  GunlukBeslenmeModel _yerelOgunEkle(
    String tarih,
    String ogunTipi,
    OgunKaydiModel yeniKayit,
  ) {
    final mevcut = state.veri ?? GunlukBeslenmeModel(tarih: tarih);
    final kopyaOgunler = <String, List<OgunKaydiModel>>{
      for (final entry in mevcut.ogunler.entries)
        entry.key: List<OgunKaydiModel>.from(entry.value),
    };
    kopyaOgunler.putIfAbsent(ogunTipi, () => <OgunKaydiModel>[]).add(yeniKayit);
    return mevcut.copyWith(ogunler: kopyaOgunler).toplamlarlaYenile();
  }

  GunlukBeslenmeModel _yerelOgunGuncelle(
    String tarih,
    OgunKaydiModel guncelKayit,
  ) {
    final mevcut = state.veri ?? GunlukBeslenmeModel(tarih: tarih);
    final kopyaOgunler = <String, List<OgunKaydiModel>>{
      for (final entry in mevcut.ogunler.entries)
        entry.key: [
          for (final item in entry.value)
            if (item.id == guncelKayit.id) guncelKayit else item,
        ],
    };
    return mevcut.copyWith(ogunler: kopyaOgunler).toplamlarlaYenile();
  }

  GunlukBeslenmeModel _yerelOgunSil(String tarih, int id) {
    final mevcut = state.veri ?? GunlukBeslenmeModel(tarih: tarih);
    final kopyaOgunler = <String, List<OgunKaydiModel>>{
      for (final entry in mevcut.ogunler.entries)
        entry.key: entry.value.where((item) => item.id != id).toList(),
    };
    return mevcut.copyWith(ogunler: kopyaOgunler).toplamlarlaYenile();
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

/// Beslenme ekranının durumunu sağlayan provider.
///
/// Oturumdaki kullanıcı kimliğini İZLER (`select`): çıkış yapıldığında
/// (id -> null) veya başka bir hesapla giriş yapıldığında (id A -> B)
/// denetleyici otomatik olarak atılır ve sıfırdan oluşturulur. Böylece
/// önceki kullanıcının bellek içi beslenme verisi yeni oturuma taşınmaz;
/// bu, çıkışın hangi yoldan (profil ekranı, zorunlu oturum sonlandırma vb.)
/// yapıldığından bağımsız olarak garanti edilir.
final beslenmeProvider =
    StateNotifierProvider<BeslenmeDenetleyici, BeslenmeDurumu>((ref) {
      final kullaniciId = ref.watch(
        oturumDenetleyiciProvider.select((s) => s.profile?.id),
      );
      return BeslenmeDenetleyici(ref, kullaniciId: kullaniciId);
    });
