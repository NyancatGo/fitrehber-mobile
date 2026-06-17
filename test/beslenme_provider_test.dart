import 'package:fitrehber_mobile/features/beslenme/providers/beslenme_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeBeslenmeTarih', () {
    test('gelecek tarihi bugune kirpar', () {
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));
      final todayText =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final tomorrowText =
          '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';

      expect(normalizeBeslenmeTarih(tomorrowText), todayText);
    });

    test('gecmis tarihi oldugu gun formatinda korur', () {
      expect(normalizeBeslenmeTarih('2026-01-05'), '2026-01-05');
    });

    test('gecersiz tarih bugune duser', () {
      final now = DateTime.now();
      final todayText =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      expect(normalizeBeslenmeTarih('gecersiz'), todayText);
    });
  });
}
