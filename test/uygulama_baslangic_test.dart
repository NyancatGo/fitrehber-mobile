import 'package:fitrehber_mobile/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'uygulama, oturum geri yükleme bitmeden yükleme ekranıyla açılır',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});

      await tester.pumpWidget(
        const ProviderScope(child: FitRehberUygulamasi()),
      );

      expect(find.text('FitRehber'), findsOneWidget);
      expect(find.text('Hesabın hazırlanıyor'), findsOneWidget);
      expect(find.text('Verilerin senkronize ediliyor'), findsOneWidget);
    },
  );

  testWidgets('token bulunamayınca uygulama giriş ekranını açar', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: FitRehberUygulamasi()));
    await tester.pumpAndSettle();

    expect(find.text('FitRehber'), findsOneWidget);
    expect(find.text('Hesabına giriş yap'), findsOneWidget);
    expect(find.text('Giriş Yap'), findsOneWidget);
  });
}
