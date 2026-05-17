import 'package:fitrehber_mobile/shared/models/icerik_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> base(Map<String, dynamic> extra) => {
        'id': 1,
        'baslik': 'Başlık',
        'tur': 'soru',
        'tarih': '2026-05-17',
        'yazar': {'username': 'baran'},
        ...extra,
      };

  group('IcerikModel.yorumSayisi', () {
    test('parses integer yorum_sayisi from the list endpoint', () {
      final icerik = IcerikModel.fromJson(base({'yorum_sayisi': 7}));
      expect(icerik.yorumSayisi, 7);
    });

    test('parses string-typed yorum_sayisi', () {
      final icerik = IcerikModel.fromJson(base({'yorum_sayisi': '12'}));
      expect(icerik.yorumSayisi, 12);
    });

    test('defaults to 0 when yorum_sayisi is absent (e.g. detail endpoint)', () {
      final icerik = IcerikModel.fromJson(base({}));
      expect(icerik.yorumSayisi, 0);
    });

    test('defaults to 0 when yorum_sayisi is unparseable', () {
      final icerik = IcerikModel.fromJson(base({'yorum_sayisi': 'abc'}));
      expect(icerik.yorumSayisi, 0);
    });
  });

  group('IcerikModel ozet & okumaSuresi', () {
    test('parses ozet and okuma_suresi from the API payload', () {
      final icerik = IcerikModel.fromJson(base({
        'ozet': 'Kısa bir özet metni',
        'okuma_suresi': 4,
      }));
      expect(icerik.ozet, 'Kısa bir özet metni');
      expect(icerik.okumaSuresi, 4);
    });

    test('defaults ozet to empty and okumaSuresi to 0 when absent', () {
      final icerik = IcerikModel.fromJson(base({}));
      expect(icerik.ozet, '');
      expect(icerik.okumaSuresi, 0);
    });

    test('parses string-typed okuma_suresi', () {
      final icerik = IcerikModel.fromJson(base({'okuma_suresi': '7'}));
      expect(icerik.okumaSuresi, 7);
    });

    test('copyWith preserves ozet and okumaSuresi', () {
      final icerik = IcerikModel.fromJson(base({
        'ozet': 'orijinal',
        'okuma_suresi': 5,
      }));
      final kopya = icerik.copyWith(yorumSayisi: 3);
      expect(kopya.ozet, 'orijinal');
      expect(kopya.okumaSuresi, 5);
    });
  });

  group('IcerikModel basics', () {
    test('exposes author and category helper getters', () {
      final icerik = IcerikModel.fromJson(base({
        'kategori': {'isim': 'Fitness'},
      }));
      expect(icerik.yazarAdi, 'baran');
      expect(icerik.kategoriAdi, 'Fitness');
    });

    test('falls back to defaults for missing author/category', () {
      final icerik = IcerikModel.fromJson({
        'id': 2,
        'baslik': 'x',
        'tur': 'haber',
        'tarih': '2026-05-17',
      });
      expect(icerik.yazarAdi, 'Anonim');
      expect(icerik.kategoriAdi, 'Genel');
    });
  });
}
