import 'package:fitrehber_mobile/shared/widgets/oturum_yukleme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('OturumYuklemeEkrani varsayılan oturum metnini gösterir', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: OturumYuklemeEkrani()));

    expect(find.text('FitRehber'), findsOneWidget);
    expect(find.text('Hesabın hazırlanıyor'), findsOneWidget);
    expect(find.text('Verilerin senkronize ediliyor'), findsOneWidget);
  });

  testWidgets('OturumYuklemeKatmani giriş metnini gösterir', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              SizedBox.expand(),
              OturumYuklemeKatmani(
                title: 'Giriş yapılıyor',
                subtitle: 'Profilin hazırlanıyor',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Giriş yapılıyor'), findsOneWidget);
    expect(find.text('Profilin hazırlanıyor'), findsOneWidget);
  });

  testWidgets('OturumYuklemeKatmani kayıt metnini gösterir', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              SizedBox.expand(),
              OturumYuklemeKatmani(
                title: 'Hesabın oluşturuluyor',
                subtitle: 'FitRehber profilin hazırlanıyor',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Hesabın oluşturuluyor'), findsOneWidget);
    expect(find.text('FitRehber profilin hazırlanıyor'), findsOneWidget);
  });

  testWidgets('OturumYuklemeKatmani ilk kurulum metnini gösterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              SizedBox.expand(),
              OturumYuklemeKatmani(
                title: 'Profilin kaydediliyor',
                subtitle: 'Hedeflerin senkronize ediliyor',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Profilin kaydediliyor'), findsOneWidget);
    expect(find.text('Hedeflerin senkronize ediliyor'), findsOneWidget);
  });
}
