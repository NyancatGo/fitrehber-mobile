import 'package:fitrehber_mobile/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app starts on session loading before auth restore finishes', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    expect(find.text('FitRehber'), findsOneWidget);
    expect(find.text('Hesabın hazırlanıyor'), findsOneWidget);
    expect(find.text('Verilerin senkronize ediliyor'), findsOneWidget);
  });

  testWidgets('app opens login screen when restore finds no token', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();

    expect(find.text('FitRehber'), findsOneWidget);
    expect(find.text('Hesabına giriş yap'), findsOneWidget);
    expect(find.text('Giriş Yap'), findsOneWidget);
  });
}
