import 'package:flutter_test/flutter_test.dart';

import 'package:fitrehber_mobile/main.dart';

void main() {
  testWidgets('app opens on login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('FitRehber'), findsOneWidget);
    expect(find.text('Hesabına giriş yap'), findsOneWidget);
    expect(find.text('Giriş Yap'), findsOneWidget);
  });
}
