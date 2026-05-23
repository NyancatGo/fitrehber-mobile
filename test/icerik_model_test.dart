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
    test(
      'liste uç noktasından gelen sayısal yorum_sayisi değerini ayrıştırır',
      () {
        final icerik = IcerikModel.fromJson(base({'yorum_sayisi': 7}));
        expect(icerik.yorumSayisi, 7);
      },
    );

    test('metin tipindeki yorum_sayisi değerini ayrıştırır', () {
      final icerik = IcerikModel.fromJson(base({'yorum_sayisi': '12'}));
      expect(icerik.yorumSayisi, 12);
    });

    test('yorum_sayisi yoksa 0 varsayar (ör. detay uç noktası)', () {
      final icerik = IcerikModel.fromJson(base({}));
      expect(icerik.yorumSayisi, 0);
    });

    test('yorum_sayisi ayrıştırılamazsa 0 varsayar', () {
      final icerik = IcerikModel.fromJson(base({'yorum_sayisi': 'abc'}));
      expect(icerik.yorumSayisi, 0);
    });
  });

  group('IcerikModel ozet & okumaSuresi', () {
    test('API gövdesinden ozet ve okuma_suresi ayrıştırır', () {
      final icerik = IcerikModel.fromJson(
        base({'ozet': 'Kısa bir özet metni', 'okuma_suresi': 4}),
      );
      expect(icerik.ozet, 'Kısa bir özet metni');
      expect(icerik.okumaSuresi, 4);
    });

    test('ozet yoksa boş, okumaSuresi yoksa 0 varsayar', () {
      final icerik = IcerikModel.fromJson(base({}));
      expect(icerik.ozet, '');
      expect(icerik.okumaSuresi, 0);
    });

    test('metin tipindeki okuma_suresi değerini ayrıştırır', () {
      final icerik = IcerikModel.fromJson(base({'okuma_suresi': '7'}));
      expect(icerik.okumaSuresi, 7);
    });

    test('copyWith ozet ve okumaSuresi alanlarını korur', () {
      final icerik = IcerikModel.fromJson(
        base({'ozet': 'orijinal', 'okuma_suresi': 5}),
      );
      final kopya = icerik.copyWith(yorumSayisi: 3);
      expect(kopya.ozet, 'orijinal');
      expect(kopya.okumaSuresi, 5);
    });
  });

  group('IcerikModel temel alanlar', () {
    test('yazar ve kategori yardımcı getterlarını sunar', () {
      final icerik = IcerikModel.fromJson(
        base({
          'kategori': {'isim': 'Fitness'},
        }),
      );
      expect(icerik.yazarAdi, 'baran');
      expect(icerik.kategoriAdi, 'Fitness');
    });

    test('yazar/kategori eksikse varsayılanlara döner', () {
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
