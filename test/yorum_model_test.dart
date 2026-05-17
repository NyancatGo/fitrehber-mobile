import 'package:fitrehber_mobile/shared/models/yorum_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('YorumModel.fromJson', () {
    test('parses a standard API payload', () {
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

    test('handles string-typed parent/depth and missing yazar', () {
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

    test('defaults depth to 0 when unparseable', () {
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

    test('builds a nested tree from a flat list', () {
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

    test('treats a comment with a missing parent as a root', () {
      final duz = [
        YorumModel.fromJson(raw(10, 999)),
      ];

      final kokler = YorumModel.agacKur(duz);

      expect(kokler.length, 1);
      expect(kokler[0].id, 10);
    });

    test('returns an empty list for empty input', () {
      expect(YorumModel.agacKur([]), isEmpty);
    });
  });

  group('YorumModel.toplamSayi', () {
    test('counts a comment and all of its nested replies', () {
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

    test('is 1 for a leaf comment', () {
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

    test('renders "Az önce" for a very recent date', () {
      final yorum = withDate(DateTime.now().subtract(const Duration(seconds: 10)));
      expect(yorum.tarihGoreli, 'Az önce');
    });

    test('renders minutes', () {
      final yorum = withDate(DateTime.now().subtract(const Duration(minutes: 5)));
      expect(yorum.tarihGoreli, '5 dk önce');
    });

    test('renders hours', () {
      final yorum = withDate(DateTime.now().subtract(const Duration(hours: 3)));
      expect(yorum.tarihGoreli, '3 sa önce');
    });

    test('renders days', () {
      final yorum = withDate(DateTime.now().subtract(const Duration(days: 4)));
      expect(yorum.tarihGoreli, '4 gün önce');
    });

    test('renders months', () {
      final yorum = withDate(DateTime.now().subtract(const Duration(days: 90)));
      expect(yorum.tarihGoreli, '3 ay önce');
    });

    test('falls back to the raw string for an invalid date', () {
      final yorum = YorumModel.fromJson({
        'id': 1,
        'mesaj': 'm',
        'tarih': 'gecersiz',
        'depth': 0,
      });
      expect(yorum.tarihGoreli, 'gecersiz');
    });
  });

  group('YorumModel like fields', () {
    test('parses begeni_sayisi and begendim from the API payload', () {
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

    test('defaults like fields when absent', () {
      final yorum = YorumModel.fromJson({
        'id': 1,
        'mesaj': 'm',
        'tarih': '',
        'depth': 0,
      });
      expect(yorum.begeniSayisi, 0);
      expect(yorum.begendim, isFalse);
    });

    test('like fields are mutable for toggle updates', () {
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

    test('exposes the author id when present', () {
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
    test('parses the liked-comment summary payload', () {
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

    test('handles a missing icerik reference', () {
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
