// İlk kurulum ekranı: cinsiyet için "Belirtmem" kaldırıldı, kullanıcı
// Erkek/Kadın seçimini açıkça yapmalı. Fitness hedefi ise serbest metin yerine
// sadece 3 seçenekten biri olmalı.
//
// PageView tembel yüklendiği için 2. adımdaki widget'lar doğrudan test
// edilemez. Bunun yerine:
//   - 0. adım arayüz iddiaları (Belirtmem yok, varsayılan seçim yok)
//   - "İleri" dokunuşu, 0. adımda cinsiyet boşken bloke oluyor mu
//   - Dışarı açılan onboardingGoalChoices listesi 3 sabit hedef içeriyor mu

import 'package:fitrehber_mobile/features/ilk_kurulum/ilk_kurulum_ekrani.dart';
import 'package:fitrehber_mobile/shared/api_servisi.dart';
import 'package:fitrehber_mobile/shared/kimlik_servisi.dart';
import 'package:fitrehber_mobile/shared/ilk_kurulum_sabitleri.dart';
import 'package:fitrehber_mobile/shared/oturum_denetleyici.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget sarmala() => ProviderScope(
    overrides: [
      // İlk kurulum initState içinde oturumDenetleyiciProvider.profile okuyor;
      // override edilmezse gerçek auth/network akışı çalışmaya kalkar.
      oturumDenetleyiciProvider.overrideWith(
        (ref) => _SahteOturumDenetleyici(),
      ),
    ],
    child: const MaterialApp(home: IlkKurulumEkrani()),
  );

  test('onboardingGoalChoices tam olarak üç sabit hedef içerir', () {
    // API ONBOARDING_GOAL_CHOICES ile birebir aynı olmalı.
    expect(onboardingGoalChoices, [
      'Yağ kaybı',
      'Kas kazanımı',
      'Kondisyon ve genel sağlık',
    ]);
  });

  testWidgets('kimlik adımında sadece Erkek/Kadın vardır ve ön seçim yoktur', (
    tester,
  ) async {
    await tester.pumpWidget(sarmala());
    await tester.pump();

    // SegmentedButton sadece 2 seçenek göstermeli.
    expect(find.text('Erkek'), findsOneWidget);
    expect(find.text('Kadın'), findsOneWidget);
    expect(find.text('Belirtmem'), findsNothing);
  });

  testWidgets('ad boşsa ileri butonu ilk adımda kalır', (tester) async {
    await tester.pumpWidget(sarmala());
    await tester.pump();

    // Ad/Soyad boşken İleri'ye basınca uyarı gelmeli, adım değişmemeli.
    await tester.tap(find.text('İleri'));
    await tester.pump(); // snackbar frame
    expect(find.text('Adını gir.'), findsOneWidget);
  });

  testWidgets('cinsiyet seçilmezse ileri butonu ilk adımda kalır', (
    tester,
  ) async {
    await tester.pumpWidget(sarmala());
    await tester.pump();

    // Ad/Soyad doldurulur ki bloklama cinsiyet eksikliğinden gelsin.
    await tester.enterText(find.widgetWithText(TextFormField, 'Ad'), 'Test');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Soyad'),
      'Kullanıcı',
    );

    // İleri butonuna bas: cinsiyet seçilmediği için uyarı snackbar gelmeli
    // ve adım değişmemeli.
    await tester.tap(find.text('İleri'));
    await tester.pump(); // snackbar frame
    expect(find.text('Cinsiyet seç.'), findsOneWidget);
    // Hala 0. adımdayız; Erkek/Kadın seçenekleri görünür olmalı.
    expect(find.text('Erkek'), findsOneWidget);
  });

  testWidgets('ilk adımda yalnızca Ad/Soyad TextFormField alanları vardır', (
    tester,
  ) async {
    // İlk kurulumun 0. adımında Ad + Soyad (zorunlu) + SegmentedButton + tarih
    // seçici var. Boy/kilo 1. adımda, hedef kilo 2. adımda; PageView tembel.
    await tester.pumpWidget(sarmala());
    await tester.pump();
    // Yalnız Ad ve Soyad: 2 TextFormField.
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.widgetWithText(TextFormField, 'Ad'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Soyad'), findsOneWidget);
  });
}

/// OturumDenetleyici'nin oturumuGeriYukle() içinde flutter_secure_storage'a
/// başvurmasını önlemek için sahte denetleyici. State zaten profil yok
/// (kullanıcı ilk kuruluma yeni gelmiş gibi); arayüz varsayılan değerlerle
/// başlar.
class _SahteOturumDenetleyici extends OturumDenetleyici {
  _SahteOturumDenetleyici()
    : super(kimlikServisi: KimlikServisi(), apiServisi: ApiServisi()) {
    state = const OturumDurumu(isLoading: false);
  }

  @override
  Future<void> oturumuGeriYukle() async {
    // İşlem yok: testlerde gerçek storage'a dokunma.
  }
}
