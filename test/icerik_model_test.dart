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
