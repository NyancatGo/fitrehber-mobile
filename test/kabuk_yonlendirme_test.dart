import 'package:fitrehber_mobile/core/router/uygulama_yonlendirici.dart';
import 'package:fitrehber_mobile/features/ana_sayfa/ana_sayfa_ekrani.dart';
import 'package:fitrehber_mobile/shared/api_servisi.dart';
import 'package:fitrehber_mobile/shared/kimlik_servisi.dart';
import 'package:fitrehber_mobile/shared/oturum_denetleyici.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _CikisYapmisOturumDenetleyici extends OturumDenetleyici {
  _CikisYapmisOturumDenetleyici()
    : super(kimlikServisi: KimlikServisi(), apiServisi: ApiServisi()) {
    state = const OturumDurumu(isLoading: false);
  }

  @override
  Future<void> oturumuGeriYukle() async {}
}

GoRouter _uretimYonlendiricisi() {
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
  return router;
}

List<RouteMatchBase> _duzlestir(List<RouteMatchBase> eslesmeler) {
  final sonuc = <RouteMatchBase>[];
  for (final eslesme in eslesmeler) {
    sonuc.add(eslesme);
    if (eslesme is ShellRouteMatch) {
      sonuc.addAll(_duzlestir(eslesme.matches));
    }
  }
  return sonuc;
}

GoRoute _sonGoRota(RouteMatchList liste) {
  return _duzlestir(
    liste.matches,
  ).map((eslesme) => eslesme.route).whereType<GoRoute>().last;
}

void main() {
  test('beş sekme tek kabuktadır, tam sayfalar kabuğun dışındadır', () {
    final router = _uretimYonlendiricisi();
    final rotalar = router.configuration.routes;
    final kabuk = rotalar.whereType<StatefulShellRoute>().single;

    expect(kabuk.branches.map((dal) => (dal.routes.single as GoRoute).path), [
      '/',
      '/forum',
      '/asistan',
      '/beslenme',
      '/profil',
    ]);

    final forum = kabuk.branches[1].routes.single as GoRoute;
    final soruSor = forum.routes.single as GoRoute;
    expect(soruSor.path, 'soru-sor');
    expect(soruSor.parentNavigatorKey, router.configuration.navigatorKey);

    final disYollar = rotalar.whereType<GoRoute>().map((rota) => rota.path);
    expect(disYollar, isNot(contains('/')));
    expect(disYollar, isNot(contains('/forum')));
    expect(
      disYollar,
      containsAll([
        '/kategoriler',
        '/arama',
        '/profil/:id',
        '/makale/:id',
        '/makale/:id/yorum/:yorumId',
      ]),
    );

    expect(
      _sonGoRota(router.configuration.findMatch(Uri.parse('/forum'))).path,
      '/forum',
    );
    expect(
      router.configuration
          .findMatch(Uri.parse('/forum'))
          .matches
          .any((eslesme) => eslesme.route is StatefulShellRoute),
      isTrue,
    );

    final soru = router.configuration.findMatch(Uri.parse('/forum/soru-sor'));
    expect(_sonGoRota(soru).path, 'soru-sor');
    expect(
      _sonGoRota(soru).parentNavigatorKey,
      router.configuration.navigatorKey,
    );

    expect(
      _sonGoRota(router.configuration.findMatch(Uri.parse('/profil/9'))).path,
      '/profil/:id',
    );
    expect(
      router.configuration
          .findMatch(Uri.parse('/arama'))
          .matches
          .any((eslesme) => eslesme.route is StatefulShellRoute),
      isFalse,
    );
    expect(
      _sonGoRota(
        router.configuration.findMatch(Uri.parse('/makale/3/yorum/4')),
      ).path,
      '/makale/:id/yorum/:yorumId',
    );
  });

  testWidgets('sekme değişince dalın durumu durur, tam sayfa çubuğu kapatır', (
    tester,
  ) async {
    final kokAnahtari = GlobalKey<NavigatorState>(debugLabel: 'test-kok');
    final router = GoRouter(
      navigatorKey: kokAnahtari,
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return AnaSayfaEkrani(navigationShell: navigationShell);
          },
          branches: [
            for (final yol in ['/', '/forum', '/asistan', '/beslenme'])
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: yol,
                    builder: (context, state) => _DurumluSayfa(etiket: yol),
                  ),
                ],
              ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profil',
                  builder: (context, state) =>
                      const _DurumluSayfa(etiket: '/profil'),
                  routes: [
                    GoRoute(
                      path: 'detay',
                      parentNavigatorKey: kokAnahtari,
                      builder: (context, state) =>
                          const Scaffold(body: Text('tam ekran')),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    // Asistan ikonu sürekli döngüde olduğu için pumpAndSettle bitmez.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(find.byType(TextField), 'yarım yazı');
    final anaDurum = tester.state<_DurumluSayfaDurumu>(
      find.byType(_DurumluSayfa),
    );

    await tester.tap(find.text('Forum'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('/forum', skipOffstage: true), findsOneWidget);
    expect(
      identical(
        anaDurum,
        tester.state<_DurumluSayfaDurumu>(
          find.byWidgetPredicate(
            (widget) => widget is _DurumluSayfa && widget.etiket == '/',
            skipOffstage: false,
          ),
        ),
      ),
      isTrue,
    );
    expect(anaDurum.controller.text, 'yarım yazı');

    router.push('/profil/detay');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('tam ekran'), findsOneWidget);
    expect(
      ModalRoute.of(tester.element(find.text('tam ekran')))!.isCurrent,
      isTrue,
    );
    expect(
      ModalRoute.of(tester.element(find.byType(NavigationBar)))!.isCurrent,
      isFalse,
    );

    router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(anaDurum.controller.text, 'yarım yazı');
    expect(
      ModalRoute.of(tester.element(find.byType(NavigationBar)))!.isCurrent,
      isTrue,
    );
  });
}

class _DurumluSayfa extends StatefulWidget {
  const _DurumluSayfa({required this.etiket});

  final String etiket;

  @override
  State<_DurumluSayfa> createState() => _DurumluSayfaDurumu();
}

class _DurumluSayfaDurumu extends State<_DurumluSayfa> {
  final TextEditingController controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text(widget.etiket),
          TextField(controller: controller),
        ],
      ),
    );
  }
}
