// BeslenmeHesaplayici: kalori hedefi hesaplamasinin onboarding'deki uc sabit
// fitness_hedefi degeriyle (Yağ kaybı, Kas kazanımı, Kondisyon ve genel
// sağlık) dogru sekilde calistigini kilitler.
//
// Onceki bug: 'Yağ kaybı' cut pattern'de degildi, kullanici icin TDEE −300
// hesaplanmiyordu. Bu test bunu engelliyor.

import 'package:fitrehber_mobile/shared/models/profil_model.dart';
import 'package:fitrehber_mobile/shared/utils/beslenme_hesaplayici.dart';
import 'package:flutter_test/flutter_test.dart';

ProfilModel _profile({required String goal}) => ProfilModel(
  id: 1,
  username: 'tester',
  email: 'tester@example.com',
  firstName: '',
  lastName: '',
  avatarUrl: null,
  bio: '',
  height: 180,
  weight: 80,
  targetWeight: 75,
  startWeight: 80,
  goal: goal,
  gender: 'E',
  isOnboarded: true,
  birthDate: DateTime(1998, 3, 12),
  joinDate: null,
  customWaterGoalMl: null,
  isStaff: false,
  isSuperuser: false,
  postCount: 0,
  achievements: const [],
  dailyActivity: GunlukAktiviteOzeti(averageMinutes: 0, days: const []),
  recentActivities: const [],
);

void main() {
  group('BeslenmeHesaplayici hedefe göre TDEE düzeltmesi', () {
    test('Yağ kaybı 300 kcal düşüş uygular', () {
      final cut = BeslenmeHesaplayici.calculate(_profile(goal: 'Yağ kaybı'));
      final maintain = BeslenmeHesaplayici.calculate(
        _profile(goal: 'Kondisyon ve genel sağlık'),
      );
      // Cut TDEE = maintain TDEE - 300 (clamp 1200..5000 yine ayni grupta)
      expect(maintain.kaloriHedef - cut.kaloriHedef, 300);
    });

    test('Kas kazanımı 300 kcal artış uygular', () {
      final bulk = BeslenmeHesaplayici.calculate(
        _profile(goal: 'Kas kazanımı'),
      );
      final maintain = BeslenmeHesaplayici.calculate(
        _profile(goal: 'Kondisyon ve genel sağlık'),
      );
      expect(bulk.kaloriHedef - maintain.kaloriHedef, 300);
    });

    test('Kondisyon ve genel sağlık koruma TDEE değerini kullanır', () {
      final maintain = BeslenmeHesaplayici.calculate(
        _profile(goal: 'Kondisyon ve genel sağlık'),
      );
      // Direkt maintenance — adjustment yok demek, BMR×1.375 sonucu.
      // Burada yalniz pozitif ve >1200 olmasini test ediyoruz; clamp
      // calismadigi senaryolar icin gerekli.
      expect(maintain.kaloriHedef, greaterThan(1200));
      expect(maintain.kaloriHedef, lessThan(5000));
    });

    test('Eski yazım "Kas kazanimi" yine kalori artışı uygular', () {
      // DB'de eski yazimla kalmis kullanicilar icin geri uyumluluk.
      final legacyBulk = BeslenmeHesaplayici.calculate(
        _profile(goal: 'Kas kazanimi'),
      );
      final maintain = BeslenmeHesaplayici.calculate(
        _profile(goal: 'Kondisyon ve genel sağlık'),
      );
      expect(legacyBulk.kaloriHedef - maintain.kaloriHedef, 300);
    });

    test('ASCII yazım "yag kaybi" de kalori düşüşü uygular', () {
      // Eski yazim/ASCII fallback varyasyonlari icin pattern coverage.
      final cut = BeslenmeHesaplayici.calculate(_profile(goal: 'yag kaybi'));
      final maintain = BeslenmeHesaplayici.calculate(
        _profile(goal: 'Kondisyon ve genel sağlık'),
      );
      expect(maintain.kaloriHedef - cut.kaloriHedef, 300);
    });
  });
}
