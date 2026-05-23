import 'package:fitrehber_mobile/core/router/uygulama_yonlendirici.dart';
import 'package:fitrehber_mobile/features/kimlik/eposta_dogrulama_ekrani.dart';
import 'package:fitrehber_mobile/features/kimlik/sifremi_unuttum_ekrani.dart';
import 'package:fitrehber_mobile/shared/api_servisi.dart';
import 'package:fitrehber_mobile/shared/kimlik_servisi.dart';
import 'package:fitrehber_mobile/shared/oturum_denetleyici.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _CikisYapmisOturumDenetleyici extends OturumDenetleyici {
  _CikisYapmisOturumDenetleyici()
    : super(kimlikServisi: KimlikServisi(), apiServisi: ApiServisi()) {
    state = const OturumDurumu(isLoading: false);
  }

  @override
  Future<void> oturumuGeriYukle() async {}
}

Future<void> _pumpRoute(WidgetTester tester, String location) async {
  final container = ProviderContainer(
    overrides: [
      oturumDenetleyiciProvider.overrideWith(
        (ref) => _CikisYapmisOturumDenetleyici(),
      ),
    ],
  );
  addTearDown(container.dispose);

  final router = container.read(uygulamaYonlendiriciProvider);
  addTearDown(router.dispose);
  router.go(location);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('e-posta doğrulama rotası çıkış yapılmışken erişilebilir', (
    tester,
  ) async {
    await _pumpRoute(tester, '/email-dogrulama?email=test@example.com');

    expect(find.byType(EpostaDogrulamaEkrani), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('şifremi unuttum rotası çıkış yapılmışken erişilebilir', (
    tester,
  ) async {
    await _pumpRoute(tester, '/sifremi-unuttum');

    expect(find.byType(SifremiUnuttumEkrani), findsOneWidget);
  });
}
