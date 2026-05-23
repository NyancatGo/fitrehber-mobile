import 'package:fitrehber_mobile/shared/models/yorum_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('YorumModel.fromJson', () {
    test('standart API gövdesini ayrıştırır', () {
      final yorum = YorumModel.fromJson({
        'id': 12,
        'mesaj': 'Harika bir cevap.',
        'tarih': '2026-05-17T10:00:00Z',
        'parent': null,
        'depth': 0,
        'yazar': {'username': 'baran'},
      });

      expect(yorum.id, 12);
      expect(yorum.mesaj, 'Harika bir cevap.');
      expect(yorum.parent, isNull);
      expect(yorum.depth, 0);
      expect(yorum.yazarAdi, 'baran');
      expect(yorum.yanitlar, isEmpty);
    });

    test('metin tipindeki parent/depth ve eksik yazarı işler', () {
      final yorum = YorumModel.fromJson({
        'id': 3,
        'mesaj': 'Cevap',
        'tarih': '',
        'parent': '5',
        'depth': '2',
      });

      expect(yorum.parent, 5);
      expect(yorum.depth, 2);
      expect(yorum.yazarAdi, 'Anonim');
    });

    test('depth ayrıştırılamazsa 0 varsayar', () {
      final yorum = YorumModel.fromJson({
        'id': 1,
        'mesaj': 'x',
        'tarih': '',
        'depth': 'abc',
      });

      expect(yorum.depth, 0);
    });
  });

  group('YorumModel.agacKur', () {
    Map<String, dynamic> raw(int id, int? parent) => {
      'id': id,
      'mesaj': 'm$id',
      'tarih': '',
      'parent': parent,
      'depth': 0,
      'yazar': {'username': 'u$id'},
    };

    test('düz listeden iç içe ağaç kurar', () {
      final duz = [
        YorumModel.fromJson(raw(1, null)),
        YorumModel.fromJson(raw(2, 1)),
        YorumModel.fromJson(raw(3, 2)),
        YorumModel.fromJson(raw(4, null)),
      ];

      final kokler = YorumModel.agacKur(duz);

      expect(kokler.length, 2);
      expect(kokler[0].id, 1);
      expect(kokler[0].yanitlar.length, 1);
      expect(kokler[0].yanitlar[0].id, 2);
      expect(kokler[0].yanitlar[0].yanitlar[0].id, 3);
      expect(kokler[1].id, 4);
      expect(kokler[1].yanitlar, isEmpty);
    });

    test('parent bulunamazsa yorumu kök kabul eder', () {
      final duz = [YorumModel.fromJson(raw(10, 999))];

      final kokler = YorumModel.agacKur(duz);

      expect(kokler.length, 1);
      expect(kokler[0].id, 10);
    });

    test('boş girdi için boş liste döner', () {
      expect(YorumModel.agacKur([]), isEmpty);
    });
  });

  group('YorumModel.toplamSayi', () {
    test('yorumu ve tüm iç içe yanıtlarını sayar', () {
      final duz = [
        YorumModel.fromJson({
          'id': 1,
          'mesaj': 'm',
          'tarih': '',
          'parent': null,
          'depth': 0,
        }),
        YorumModel.fromJson({
          'id': 2,
          'mesaj': 'm',
          'tarih': '',
          'parent': 1,
          'depth': 1,
        }),
        YorumModel.fromJson({
          'id': 3,
          'mesaj': 'm',
          'tarih': '',
          'parent': 2,
          'depth': 2,
        }),
      ];

      final kokler = YorumModel.agacKur(duz);

      expect(kokler.first.toplamSayi, 3);
    });

    test('yanıtsız yorum için 1 olur', () {
      final yorum = YorumModel.fromJson({
        'id': 1,
        'mesaj': 'm',
        'tarih': '',
        'depth': 0,
      });

      expect(yorum.toplamSayi, 1);
    });
  });

  group('YorumModel.tarihGoreli', () {
    YorumModel withDate(DateTime dt) => YorumModel.fromJson({
      'id': 1,
      'mesaj': 'm',
      'tarih': dt.toUtc().toIso8601String(),
      'depth': 0,
    });

    test('çok yeni tarih için "Az önce" gösterir', () {
      final yorum = withDate(
        DateTime.now().subtract(const Duration(seconds: 10)),
      );
      expect(yorum.tarihGoreli, 'Az önce');
    });

    test('dakikayı gösterir', () {
      final yorum = withDate(
        DateTime.now().subtract(const Duration(minutes: 5)),
      );
      expect(yorum.tarihGoreli, '5 dk önce');
    });

    test('saati gösterir', () {
      final yorum = withDate(DateTime.now().subtract(const Duration(hours: 3)));
      expect(yorum.tarihGoreli, '3 sa önce');
    });

    test('günü gösterir', () {
      final yorum = withDate(DateTime.now().subtract(const Duration(days: 4)));
      expect(yorum.tarihGoreli, '4 gün önce');
    });

    test('ayı gösterir', () {
      final yorum = withDate(DateTime.now().subtract(const Duration(days: 90)));
      expect(yorum.tarihGoreli, '3 ay önce');
    });

    test('geçersiz tarih için ham metne döner', () {
      final yorum = YorumModel.fromJson({
        'id': 1,
        'mesaj': 'm',
        'tarih': 'gecersiz',
        'depth': 0,
      });
      expect(yorum.tarihGoreli, 'gecersiz');
    });
  });

  group('YorumModel beğeni alanları', () {
    test('API gövdesinden begeni_sayisi ve begendim alanlarını ayrıştırır', () {
      final yorum = YorumModel.fromJson({
        'id': 1,
        'mesaj': 'm',
        'tarih': '',
        'depth': 0,
        'begeni_sayisi': 4,
        'begendim': true,
      });
      expect(yorum.begeniSayisi, 4);
      expect(yorum.begendim, isTrue);
    });

    test('API gövdesinden yanıt bilgisini ayrıştırır', () {
      final yorum = YorumModel.fromJson({
        'id': 1,
        'mesaj': 'm',
        'tarih': '',
        'depth': 2,
        'yanit_sayisi': '2',
        'toplam_yanit_sayisi': 4,
        'has_more_replies': true,
      });

      expect(yorum.yanitSayisi, 2);
      expect(yorum.toplamYanitSayisi, 4);
      expect(yorum.hasMoreReplies, isTrue);
      expect(yorum.toplamSayi, 5);
    });

    test('beğeni alanları yoksa varsayılanları kullanır', () {
      final yorum = YorumModel.fromJson({
        'id': 1,
        'mesaj': 'm',
        'tarih': '',
        'depth': 0,
      });
      expect(yorum.begeniSayisi, 0);
      expect(yorum.begendim, isFalse);
    });

    test('toggle güncellemeleri için beğeni alanları değiştirilebilir', () {
      final yorum = YorumModel.fromJson({
        'id': 1,
        'mesaj': 'm',
        'tarih': '',
        'depth': 0,
      });
      yorum.begendim = true;
      yorum.begeniSayisi = 1;
      expect(yorum.begendim, isTrue);
      expect(yorum.begeniSayisi, 1);
    });

    test('varsa yazar id değerini sunar', () {
      final yorum = YorumModel.fromJson({
        'id': 1,
        'mesaj': 'm',
        'tarih': '',
        'depth': 0,
        'yazar': {'id': 42, 'username': 'baran'},
      });
      expect(yorum.yazarId, 42);
    });
  });

  group('YorumOzetModel.fromJson', () {
    test('beğenilen yorum özet gövdesini ayrıştırır', () {
      final ozet = YorumOzetModel.fromJson({
        'id': 9,
        'mesaj': 'Teşekkürler',
        'tarih': '2026-05-17T10:00:00Z',
        'icerik': 3,
        'icerik_baslik': 'Protein rehberi',
        'yazar': {'username': 'baran'},
      });
      expect(ozet.id, 9);
      expect(ozet.icerikId, 3);
      expect(ozet.icerikBaslik, 'Protein rehberi');
      expect(ozet.yazarAdi, 'baran');
    });

    test('eksik içerik referansını işler', () {
      final ozet = YorumOzetModel.fromJson({
        'id': 1,
        'mesaj': 'm',
        'tarih': '',
      });
      expect(ozet.icerikId, isNull);
      expect(ozet.icerikBaslik, '');
    });
  });
}
