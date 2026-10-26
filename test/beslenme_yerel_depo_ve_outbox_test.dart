import 'package:dio/dio.dart';
import 'package:fitrehber_mobile/features/beslenme/providers/beslenme_provider.dart';
import 'package:fitrehber_mobile/shared/api_servisi.dart';
import 'package:fitrehber_mobile/shared/models/beslenme_model.dart';
import 'package:fitrehber_mobile/shared/services/beslenme_yerel_depo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SahteBeslenmeApiServisi extends ApiServisi {
  bool cevrimdisi = false;

  /// `ogunEkle` çağrısında fırlatılacak HTTP hatası (null ise hata yok).
  ApiHatasi? hata;

  final List<String> cagrilar = [];
  GunlukBeslenmeModel sunucuVerisi = const GunlukBeslenmeModel(
    tarih: '2026-10-25',
    suMl: 500,
    kaloriKcal: 300,
    proteinG: 20,
    karbonhidratG: 30,
    yagG: 10,
    ogunler: {
      'sabah': [
        OgunKaydiModel(
          id: 10,
          tarih: '2026-10-25',
          ogunTipi: 'sabah',
          besinId: 1,
          besinIsim: 'Yumurta',
          miktar: 100,
          miktarBirimi: 'g',
          kalori: 300,
          protein: 20,
          karbonhidrat: 30,
          yag: 10,
        ),
      ],
      'ogle': [],
      'aksam': [],
      'atistirmalik': [],
    },
  );

  DioException _agHatasi(String path) => DioException(
    requestOptions: RequestOptions(path: path),
    type: DioExceptionType.connectionError,
    message: 'Offline',
  );

  @override
  Future<GunlukBeslenmeModel> beslenmeSuyuGetir(String tarih) async {
    cagrilar.add('get:$tarih');
    if (cevrimdisi) throw _agHatasi('/profil/beslenme-su/');
    return sunucuVerisi.copyWith(tarih: tarih);
  }

  @override
  Future<void> ogunEkle({
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
    if (cevrimdisi) throw _agHatasi('/beslenme/ekle/');
    if (hata != null) throw hata!;
    cagrilar.add('ekle:$ogunTipi:${besinIsim ?? besinId}:${miktar.toInt()}');
  }

  @override
  Future<void> ogunGuncelle({
    required int id,
    required double miktar,
    int? kalori,
    double? protein,
    double? karbonhidrat,
    double? yag,
    int? porsiyonId,
  }) async {
    if (cevrimdisi) throw _agHatasi('/beslenme/guncelle/$id/');
    if (hata != null) throw hata!;
    cagrilar.add('guncelle:$id:${miktar.toInt()}');
  }

  @override
  Future<void> ogunSil(int id) async {
    if (cevrimdisi) throw _agHatasi('/beslenme/sil/$id/');
    cagrilar.add('sil:$id');
  }

  @override
  Future<GunlukBeslenmeModel> suEkle({
    required String tarih,
    required int miktarMl,
  }) async {
    if (cevrimdisi) throw _agHatasi('/profil/beslenme-su/');
    cagrilar.add('su:$tarih:$miktarMl');
    sunucuVerisi = sunucuVerisi.copyWith(suMl: sunucuVerisi.suMl + miktarMl);
    return sunucuVerisi;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'çevrimdışı öğün ekleme/güncelleme/su ekleme yerel önbellekte tutulur ve bağlantı gelince outbox boşaltılır',
    () async {
      final api = _SahteBeslenmeApiServisi();
      final depo = BeslenmeYerelDepo();
      final notifier = BeslenmeDenetleyici(
        null,
        api: api,
        depo: depo,
        kullaniciId: 1,
        baslangicYukle: false,
      );

      // 1) Çevrimiçi ilk yükleme -> yerel önbelleğe yazılır.
      await notifier.load('2026-10-25');
      expect(notifier.state.cevrimdisiMi, isFalse);
      expect(notifier.state.veri?.kaloriKcal, 300);

      // 2) Çevrimdışına geç -> öğün ekle, öğünü güncelle ve iki kez su ekle.
      api.cevrimdisi = true;

      final ekleOk = await notifier.ogunEkle(
        ogunTipi: 'ogle',
        besinId: 5,
        besinIsim: 'Tavuk Göğsü',
        miktar: 100,
        kalori: 165,
        protein: 31,
        karbonhidrat: 0,
        yag: 3.6,
      );
      expect(ekleOk, isTrue);
      expect(notifier.state.cevrimdisiMi, isTrue);
      expect(notifier.state.bekleyenIslemSayisi, 1);
      expect(notifier.state.veri?.kaloriKcal, 465);

      final eklenenKayit = notifier.state.veri!.ogunler['ogle']!.single;
      expect(eklenenKayit.id, lessThan(0));

      // Çevrimdışı eklenen kaydın miktarını 200g'a çıkar -> kuyrukta birleştirilmeli (hâlâ 1 işlem).
      final guncelleOk = await notifier.ogunGuncelle(
        eski: eklenenKayit,
        yeniMiktar: 200,
      );
      expect(guncelleOk, isTrue);
      expect(notifier.state.bekleyenIslemSayisi, 1);
      expect(notifier.state.veri?.kaloriKcal, 630);

      // İki kez üst üste su ekle -> aynı gün olduğu için tek su_ekle işleminde birleşmeli.
      await notifier.suEkle(250);
      await notifier.suEkle(250);
      expect(notifier.state.veri?.suMl, 1000);
      expect(notifier.state.bekleyenIslemSayisi, 2);

      // 3) Bağlantı geri gelsin -> load() outbox'ı sırayla sunucuya boşaltmalı.
      api.cevrimdisi = false;
      api.cagrilar.clear();
      await notifier.load('2026-10-25');

      expect(notifier.state.cevrimdisiMi, isFalse);
      expect(notifier.state.bekleyenIslemSayisi, 0);
      expect(api.cagrilar, [
        'ekle:ogle:Tavuk Göğsü:200',
        'su:2026-10-25:500',
        'get:2026-10-25',
      ]);
    },
  );

  test(
    'çevrimdışı eklenen öğün henüz senkronlanmadan silinirse kuyruktan tamamen düşer',
    () async {
      final api = _SahteBeslenmeApiServisi()..cevrimdisi = true;
      final depo = BeslenmeYerelDepo();
      final notifier = BeslenmeDenetleyici(
        null,
        api: api,
        depo: depo,
        kullaniciId: 1,
        baslangicYukle: false,
      );

      await notifier.ogunEkle(
        ogunTipi: 'aksam',
        besinIsim: 'Elma',
        miktar: 100,
        kalori: 52,
      );
      expect(notifier.state.bekleyenIslemSayisi, 1);
      final geciciId = notifier.state.veri!.ogunler['aksam']!.single.id;

      final silOk = await notifier.ogunSil(geciciId);
      expect(silOk, isTrue);
      expect(notifier.state.bekleyenIslemSayisi, 0);
      expect(notifier.state.veri!.ogunler['aksam'], isEmpty);
      expect(notifier.state.veri!.kaloriKcal, 0);
    },
  );

  // ---------------------------------------------------------------------------
  // KULLANICI İZOLASYONU
  //
  // Çevrimdışı kuyruk ve gün önbelleği kullanıcıya bağlıdır. Aynı cihazda
  // oturum açan ikinci kullanıcı, birincinin kuyruğunu göremez ve onu
  // BOŞALTAMAZ (aksi halde A'nın öğünleri B'nin hesabına yazılırdı).
  // ---------------------------------------------------------------------------

  test('kuyruk ve gün önbelleği kullanıcıya göre ayrılır', () async {
    final depo = BeslenmeYerelDepo();

    await depo.ogunEkleKuyrugaAl(
      1,
      tarih: '2026-10-25',
      ogunTipi: 'sabah',
      besinIsim: 'A kullanıcısının yemeği',
      miktar: 100,
      kalori: 250,
    );

    // Farklı kullanıcı kendi kuyruğunu görmez.
    expect(await depo.bekleyenSayisi(1), 1);
    expect(await depo.bekleyenSayisi(2), 0);

    // Anahtarlar da farklı.
    expect(BeslenmeYerelDepo.outboxAnahtari(1), isNot(BeslenmeYerelDepo.outboxAnahtari(2)));
    expect(
      BeslenmeYerelDepo.gunAnahtari(1, '2026-10-25'),
      isNot(BeslenmeYerelDepo.gunAnahtari(2, '2026-10-25')),
    );
  });

  test('başka kullanıcının kuyruğu boşaltılmaz', () async {
    final api = _SahteBeslenmeApiServisi();
    final depo = BeslenmeYerelDepo();

    // A kullanıcısının kuyruğu.
    await depo.ogunEkleKuyrugaAl(
      1,
      tarih: '2026-10-25',
      ogunTipi: 'sabah',
      besinIsim: 'A yemeği',
      miktar: 100,
      kalori: 250,
    );

    // B kullanıcısı kuyruğunu boşaltmayı dener: A'nın işlemi GÖNDERİLMEZ.
    final kalan = await depo.kuyruguBosalt(2, api);

    expect(kalan, 0);
    expect(api.cagrilar, isEmpty);
    // A'nın işlemi kuyruğunda durmaya devam eder.
    expect(await depo.bekleyenSayisi(1), 1);
  });

  test('kuyruk sahibi değişince boşaltma durur', () async {
    final api = _SahteBeslenmeApiServisi();
    final depo = BeslenmeYerelDepo();

    await depo.ogunEkleKuyrugaAl(
      1,
      tarih: '2026-10-25',
      ogunTipi: 'sabah',
      besinIsim: 'A yemeği',
      miktar: 100,
      kalori: 250,
    );

    // `devamEtsinMi` false dönerse (kullanıcı değişti / çıkış yapıldı)
    // boşaltma HİÇBİR işlemi göndermeden durur.
    final kalan = await depo.kuyruguBosalt(
      1,
      api,
      devamEtsinMi: () => false,
    );

    expect(kalan, 1);
    expect(api.cagrilar, isEmpty);
    expect(await depo.bekleyenSayisi(1), 1);
  });

  // ---------------------------------------------------------------------------
  // GEÇİCİ / KALICI HATA AYRIMI
  //
  // 401 (oturum) ve 429 (hız sınırı) GEÇİCİ hatalardır: kuyruktaki işlem
  // düşürülmemeli, çünkü kullanıcının girdiği veri sessizce kaybolur.
  // Yalnızca sunucunun kalıcı reddettiği (400/403/404/422) işlemler düşürülür.
  // ---------------------------------------------------------------------------

  test('geçici hata (429) alındığında kuyruk korunur', () async {
    final api = _SahteBeslenmeApiServisi()
      ..hata = const ApiHatasi('Fazla istek gönderildi.', statusCode: 429);
    final depo = BeslenmeYerelDepo();

    await depo.ogunEkleKuyrugaAl(
      1,
      tarih: '2026-10-25',
      ogunTipi: 'sabah',
      besinIsim: 'Yumurta',
      miktar: 100,
      kalori: 250,
    );

    final kalan = await depo.kuyruguBosalt(1, api);

    // İşlem düşürülmemeli — kullanıcının verisi kaybolmamalı.
    expect(kalan, 1);
    expect(await depo.bekleyenSayisi(1), 1);
  });

  test('geçici hata (401) alındığında kuyruk korunur', () async {
    final api = _SahteBeslenmeApiServisi()
      ..hata = const ApiHatasi('Oturum süren dolmuş.', statusCode: 401);
    final depo = BeslenmeYerelDepo();

    await depo.ogunEkleKuyrugaAl(
      1,
      tarih: '2026-10-25',
      ogunTipi: 'sabah',
      besinIsim: 'Yumurta',
      miktar: 100,
      kalori: 250,
    );

    expect(await depo.kuyruguBosalt(1, api), 1);
    expect(await depo.bekleyenSayisi(1), 1);
  });

  test('kalıcı hata (400) alındığında bozuk işlem kuyruktan düşer', () async {
    final api = _SahteBeslenmeApiServisi()
      ..hata = const ApiHatasi('Geçersiz miktar.', statusCode: 400);
    final depo = BeslenmeYerelDepo();

    await depo.ogunEkleKuyrugaAl(
      1,
      tarih: '2026-10-25',
      ogunTipi: 'sabah',
      besinIsim: 'Yumurta',
      miktar: 100,
      kalori: 250,
    );

    final kalan = await depo.kuyruguBosalt(1, api);

    // Sunucunun kalıcı reddettiği işlem düşürülür (kuyruk sonsuza dek tıkamasın).
    expect(kalan, 0);
    expect(await depo.bekleyenSayisi(1), 0);
  });

  test('ApiHatasi geçici/kalıcı sınıflandırması', () {
    const gecici = <int>[401, 408, 425, 429, 500, 502, 503];
    const kalici = <int>[400, 403, 404, 409, 422];

    for (final kod in gecici) {
      final hata = ApiHatasi('geçici', statusCode: kod);
      expect(hata.geciciMi, isTrue, reason: '$kod geçici olmalı');
      expect(hata.kaliciMi, isFalse, reason: '$kod kalıcı olmamalı');
    }
    for (final kod in kalici) {
      final hata = ApiHatasi('kalıcı', statusCode: kod);
      expect(hata.kaliciMi, isTrue, reason: '$kod kalıcı olmalı');
      expect(hata.geciciMi, isFalse, reason: '$kod geçici olmamalı');
    }

    // Durum kodu bilinmiyorsa güvenli taraf: kalıcı sayılmaz (veri düşmez).
    const bilinmeyen = ApiHatasi('bilinmiyor');
    expect(bilinmeyen.geciciMi, isFalse);
    expect(bilinmeyen.kaliciMi, isFalse);
  });

  // ---------------------------------------------------------------------------
  // ESKİ ANAHTARLARIN TEMİZLENMESİ (v1 -> v2 geçişi)
  //
  // v1 anahtarları kullanıcıya bağlı değildi; sahibi bilinemediği için
  // ilk erişimde güvenle silinmelidir.
  // ---------------------------------------------------------------------------

  test('kullanıcıya bağlı olmayan eski v1 anahtarları temizlenir', () async {
    SharedPreferences.setMockInitialValues({
      'beslenme_outbox_v1': '[{"tur":"ogun_ekle"}]',
      'beslenme_gun_cache_v1_2026-10-25': '{"tarih":"2026-10-25"}',
      'beslenme_outbox_v2_1': '[{"tur":"ogun_ekle"}]',
    });

    final depo = BeslenmeYerelDepo();
    await depo.bekleyenSayisi(1); // ilk erişim temizliği tetikler

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('beslenme_outbox_v1'), isFalse);
    expect(prefs.containsKey('beslenme_gun_cache_v1_2026-10-25'), isFalse);
    // Kullanıcıya bağlı yeni anahtarlar korunur.
    expect(prefs.containsKey('beslenme_outbox_v2_1'), isTrue);
  });

  test('çıkışta gün önbelleği temizlenir ama gönderilmemiş kuyruk korunur', () async {
    final depo = BeslenmeYerelDepo();

    await depo.ogunEkleKuyrugaAl(
      1,
      tarih: '2026-10-25',
      ogunTipi: 'sabah',
      besinIsim: 'Yumurta',
      miktar: 100,
      kalori: 250,
    );
    await depo.gunKaydet(
      1,
      const GunlukBeslenmeModel(tarih: '2026-10-25', suMl: 500, kaloriKcal: 300),
    );

    await depo.kullaniciVerileriniTemizle(1);

    // Gün önbelleği silindi (özel veri cihazda kalmasın).
    expect(await depo.gunOku(1, '2026-10-25'), isNull);
    // Kuyruk korundu: aynı kullanıcı tekrar giriş yapınca sunucuya iletilsin.
    expect(await depo.bekleyenSayisi(1), 1);
  });
}
