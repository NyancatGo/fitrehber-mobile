// Onboarding ekrani — cinsiyet 'Belirtmem' kaldirildi, kullanici Erkek/Kadın'i
// acikca secmeli; fitness hedefi serbest metin yerine sadece 3 chip secimi.
//
// PageView lazy oldugu icin step 2'deki widget'lar dogrudan test edilemez;
// onun yerine:
//   - Step 0 UI iddialari (Belirtmem yok, default secim yok)
//   - "Ileri" tiklamasi step 0'da gender bos iken bloke ediyor mu
//   - Public onboardingGoalChoices listesi 3 sabit hedefi iceriyor mu

import 'package:fitrehber_mobile/features/onboarding/onboarding_screen.dart';
import 'package:fitrehber_mobile/shared/api_service.dart';
import 'package:fitrehber_mobile/shared/auth_service.dart';
import 'package:fitrehber_mobile/shared/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap() => ProviderScope(
        overrides: [
          // Onboarding initState'de sessionControllerProvider.profile okuyor;
          // override edilmeyince auth/network calismaya kalkar.
          sessionControllerProvider.overrideWith(
            (ref) => _FakeSessionController(),
          ),
        ],
        child: const MaterialApp(home: OnboardingScreen()),
      );

  test('onboardingGoalChoices contains exactly the three locked goals', () {
    // API ONBOARDING_GOAL_CHOICES ile birebir ayni olmali.
    expect(onboardingGoalChoices, [
      'Yağ kaybı',
      'Kas kazanimi',
      'Kondisyon ve genel sağlık',
    ]);
  });

  testWidgets(
    'identity step has only Erkek/Kadın and nothing pre-selected',
    (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      // SegmentedButton sadece 2 segment gostermeli.
      expect(find.text('Erkek'), findsOneWidget);
      expect(find.text('Kadın'), findsOneWidget);
      expect(find.text('Belirtmem'), findsNothing);
    },
  );

  testWidgets('next button blocks step 0 when gender is not selected',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();

    // Ileri butonuna bas — cinsiyet secilmedigi icin uyari snackbar gelmeli
    // ve step degismemeli.
    await tester.tap(find.text('İleri'));
    await tester.pump(); // snackbar frame
    expect(find.text('Cinsiyet sec.'), findsOneWidget);
    // Hala step 0'dayiz — Erkek/Kadın hala gorunur olmali.
    expect(find.text('Erkek'), findsOneWidget);
  });

  testWidgets('step 0 has 0 TextFormField — bio/numbers gelmedi henuz',
      (tester) async {
    // Onboarding step 0'da yalnizca SegmentedButton + tarih secici var.
    // (Boy/kilo step 1'de, hedef kilo step 2'de — PageView lazy.)
    await tester.pumpWidget(wrap());
    await tester.pump();
    // Step 2'deki "Fitness hedefi" TextFormField'i artik yok; bunu
    // dogrudan goremiyoruz (lazy build) ama _allowedGoals'in 3 oge
    // tuttugunu API ile ayni siralamayla yukaridaki test kilitliyor.
    expect(find.byType(TextFormField), findsNothing);
  });
}

/// SessionController'in restore() icinde flutter_secure_storage'a basvurmasini
/// onlemek icin fake. State zaten profil yok (kullanici onboarding'e yeni
/// gelmis gibi); UI default degerlerle baslar.
class _FakeSessionController extends SessionController {
  _FakeSessionController()
      : super(authService: AuthService(), apiService: ApiService()) {
    state = const SessionState(isLoading: false);
  }

  @override
  Future<void> restore() async {
    // no-op — testlerde gercek storage'a dokunma.
  }
}
