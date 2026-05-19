import 'package:flutter_test/flutter_test.dart';
import 'package:fitrehber_mobile/shared/models/beslenme_model.dart';

void main() {
  group('Beslenme modelleri', () {
    test('BesinModel API payloadunu parse eder', () {
      final besin = BesinModel.fromJson({
        'id': 5,
        'isim': 'Yulaf Ezmesi',
        'marka': null,
        'barkod': null,
        'kalori_100g': 389,
        'protein_100g': '16.9',
        'karbonhidrat_100g': '66.3',
        'yag_100g': '6.9',
        'is_verified': true,
      });

      expect(besin.id, 5);
      expect(besin.isim, 'Yulaf Ezmesi');
      expect(besin.protein100g, 16.9);
      expect(besin.isVerified, isTrue);
    });

    test('GunlukBeslenmeModel yeni ogun payloadunu parse eder', () {
      final gunluk = GunlukBeslenmeModel.fromJson({
        'tarih': '2026-05-19',
        'su_ml': 1500,
        'toplam_kalori': 194,
        'toplam_protein': '8.5',
        'toplam_karbonhidrat': '33.2',
        'toplam_yag': '3.5',
        'ogunler': {
          'sabah': [
            {
              'id': 9,
              'tarih': '2026-05-19',
              'ogun_tipi': 'sabah',
              'besin_id': 5,
              'besin_isim': 'Yulaf Ezmesi',
              'miktar': '50.0',
              'miktar_birimi': 'g',
              'kalori': 194,
              'protein': '8.5',
              'karbonhidrat': '33.2',
              'yag': '3.5',
            },
          ],
        },
      });

      expect(gunluk.kaloriKcal, 194);
      expect(gunluk.proteinG, 8.5);
      expect(gunluk.ogunler['sabah'], hasLength(1));
      expect(gunluk.ogunler['sabah']!.first.besinId, 5);
      expect(gunluk.ogunler['ogle'], isEmpty);
    });

    test('GunlukBeslenmeModel eski beslenme-su payloaduyla uyumlu kalır', () {
      final gunluk = GunlukBeslenmeModel.fromJson({
        'tarih': '2026-05-19',
        'su_ml': 500,
        'kalori_kcal': 700,
        'protein_g': '42.0',
        'karbonhidrat_g': '80.5',
        'yag_g': '20.0',
      });

      expect(gunluk.kaloriKcal, 700);
      expect(gunluk.proteinG, 42.0);
      expect(gunluk.ogunler['atistirmalik'], isEmpty);
    });
  });
}
