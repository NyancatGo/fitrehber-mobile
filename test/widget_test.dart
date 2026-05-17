import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:fitrehber_mobile/main.dart';

void main() {
  testWidgets('app opens on login screen', (WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pump();

    expect(find.text('FitRehber'), findsOneWidget);
    expect(find.text('Hesabına giriş yap'), findsOneWidget);
    expect(find.text('Giriş Yap'), findsOneWidget);
  });
}
