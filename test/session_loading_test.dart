import 'package:fitrehber_mobile/shared/widgets/session_loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SessionLoadingScreen renders default session copy', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SessionLoadingScreen()));

    expect(find.text('FitRehber'), findsOneWidget);
    expect(find.text('Hesabın hazırlanıyor'), findsOneWidget);
    expect(find.text('Verilerin senkronize ediliyor'), findsOneWidget);
  });

  testWidgets('SessionLoadingOverlay renders login copy', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              SizedBox.expand(),
              SessionLoadingOverlay(
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

  testWidgets('SessionLoadingOverlay renders register copy', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              SizedBox.expand(),
              SessionLoadingOverlay(
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

  testWidgets('SessionLoadingOverlay renders onboarding copy', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              SizedBox.expand(),
              SessionLoadingOverlay(
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
