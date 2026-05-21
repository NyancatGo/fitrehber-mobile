// NutritionCalculator: kalori hedefi hesaplamasinin onboarding'deki uc sabit
// fitness_hedefi degeriyle (Yağ kaybı, Kas kazanımı, Kondisyon ve genel
// sağlık) dogru sekilde calistigini kilitler.
//
// Onceki bug: 'Yağ kaybı' cut pattern'de degildi, kullanici icin TDEE −300
// hesaplanmiyordu. Bu test bunu engelliyor.

import 'package:fitrehber_mobile/shared/models/profil_model.dart';
import 'package:fitrehber_mobile/shared/utils/nutrition_calculator.dart';
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
      dailyActivity: DailyActivitySummary(averageMinutes: 0, days: const []),
      recentActivities: const [],
    );

void main() {
  group('NutritionCalculator goal-based TDEE adjustment', () {
    test('Yağ kaybı triggers −300 kcal cut adjustment', () {
      final cut = NutritionCalculator.calculate(_profile(goal: 'Yağ kaybı'));
      final maintain = NutritionCalculator.calculate(
        _profile(goal: 'Kondisyon ve genel sağlık'),
      );
      // Cut TDEE = maintain TDEE - 300 (clamp 1200..5000 yine ayni grupta)
      expect(maintain.kaloriHedef - cut.kaloriHedef, 300);
    });

    test('Kas kazanımı triggers +300 kcal bulk adjustment', () {
      final bulk = NutritionCalculator.calculate(
        _profile(goal: 'Kas kazanımı'),
      );
      final maintain = NutritionCalculator.calculate(
        _profile(goal: 'Kondisyon ve genel sağlık'),
      );
      expect(bulk.kaloriHedef - maintain.kaloriHedef, 300);
    });

    test('Kondisyon ve genel sağlık keeps maintenance TDEE', () {
      final maintain = NutritionCalculator.calculate(
        _profile(goal: 'Kondisyon ve genel sağlık'),
      );
      // Direkt maintenance — adjustment yok demek, BMR×1.375 sonucu.
      // Burada yalniz pozitif ve >1200 olmasini test ediyoruz; clamp
      // calismadigi senaryolar icin gerekli.
      expect(maintain.kaloriHedef, greaterThan(1200));
      expect(maintain.kaloriHedef, lessThan(5000));
    });

    test('Legacy "Kas kazanimi" (without ı) still triggers bulk', () {
      // DB'de eski yazimla kalmis kullanicilar icin geri uyumluluk.
      final legacyBulk = NutritionCalculator.calculate(
        _profile(goal: 'Kas kazanimi'),
      );
      final maintain = NutritionCalculator.calculate(
        _profile(goal: 'Kondisyon ve genel sağlık'),
      );
      expect(legacyBulk.kaloriHedef - maintain.kaloriHedef, 300);
    });

    test('ASCII fallback "yag kaybi" also triggers cut', () {
      // Eski yazim/ASCII fallback varyasyonlari icin pattern coverage.
      final cut = NutritionCalculator.calculate(_profile(goal: 'yag kaybi'));
      final maintain = NutritionCalculator.calculate(
        _profile(goal: 'Kondisyon ve genel sağlık'),
      );
      expect(maintain.kaloriHedef - cut.kaloriHedef, 300);
    });
  });
}
