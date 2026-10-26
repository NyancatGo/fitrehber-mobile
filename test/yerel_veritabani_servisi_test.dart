import 'package:fitrehber_mobile/shared/models/icerik_model.dart';
import 'package:fitrehber_mobile/shared/models/kategori_model.dart';
import 'package:fitrehber_mobile/shared/yerel_veritabani_servisi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('kategorileri önbelleğe yazar ve geri okur, bozuk JSON durumunda boş döner', () async {
    expect(await YerelVeritabaniServisi.getCachedKategoriler(), isEmpty);

    await YerelVeritabaniServisi.cacheKategoriler([
      KategoriModel(id: 1, isim: 'Beslenme'),
      KategoriModel(id: 2, isim: 'Antrenman'),
    ]);

    final okunan = await YerelVeritabaniServisi.getCachedKategoriler();
    expect(okunan, hasLength(2));
    expect(okunan.first.id, 1);
    expect(okunan.first.isim, 'Beslenme');

    // Bozuk JSON dayanıklılığı:
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_kategoriler', '{bozuk-json');
    expect(await YerelVeritabaniServisi.getCachedKategoriler(), isEmpty);
  });

  test('içerikleri önbelleğe yazar ve 1 saatlik bayatlık (stale) eşiğini denetler', () async {
    expect(await YerelVeritabaniServisi.isIcerikCacheStale(), isTrue);

    final ornek = IcerikModel(
      id: 42,
      baslik: 'Kreatin Rehberi',
      tur: 'haber',
      tarih: '2026-10-25',
      yazar: const {'id': 1, 'username': 'editor'},
      yazi: '<p>Merhaba</p>',
      yaziTemiz: '<p>Merhaba</p>',
      yorumSayisi: 3,
      begeniSayisi: 10,
      ozet: 'Kısa özet',
      okumaSuresi: 4,
    );

    await YerelVeritabaniServisi.cacheIcerikler([ornek]);
    expect(await YerelVeritabaniServisi.isIcerikCacheStale(), isFalse);

    final okunan = await YerelVeritabaniServisi.getCachedIcerikler();
    expect(okunan, hasLength(1));
    expect(okunan.single.id, 42);
    expect(okunan.single.baslik, 'Kreatin Rehberi');
    expect(okunan.single.okumaSuresi, 4);

    // Zaman damgasını 2 saat geriye çek -> bayat sayılmalı:
    final prefs = await SharedPreferences.getInstance();
    final ikiSaatOnce = DateTime.now()
        .subtract(const Duration(hours: 2))
        .millisecondsSinceEpoch;
    await prefs.setInt('cached_icerikler_ts', ikiSaatOnce);
    expect(await YerelVeritabaniServisi.isIcerikCacheStale(), isTrue);
  });
}
