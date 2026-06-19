import 'package:fitrehber_mobile/features/beslenme/widgets/su_takip_bolumu.dart';
import 'package:fitrehber_mobile/shared/utils/beslenme_hesaplayici.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('su takip hizli butonlari web ile ayni degerleri gonderir', (
    tester,
  ) async {
    final taps = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SuTakipBolumu(
            suMl: 0,
            hedefler: const BeslenmeHedefleri(
              kaloriHedef: 2000,
              proteinHedefG: 150,
              karbonhidratHedefG: 225,
              yagHedefG: 55,
              suHedefMl: 2500,
            ),
            onEkle: taps.add,
            isLoading: false,
          ),
        ),
      ),
    );

    for (final label in ['+200 ml', '+330 ml', '+500 ml', '-200 ml']) {
      expect(find.text(label), findsOneWidget);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    expect(taps, [200, 330, 500, -200]);
    expect(find.text('+250 ml'), findsNothing);
    expect(find.text('-250 ml'), findsNothing);
    expect(find.text('-500 ml'), findsNothing);
  });
}
