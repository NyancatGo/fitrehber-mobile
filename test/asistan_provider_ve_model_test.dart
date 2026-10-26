import 'package:fitrehber_mobile/features/asistan/providers/asistan_provider.dart';
import 'package:fitrehber_mobile/shared/api_servisi.dart';
import 'package:fitrehber_mobile/shared/models/sohbet_mesaji_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SahteAsistanApi extends ApiServisi {
  AsistanYanitModel? siradakiYanit;
  Object? siradakiHata;
  final List<String> gonderilenMesajlar = [];
  final List<List<SohbetMesajiModel>> gonderilenGecmisler = [];
  final List<Map<String, dynamic>> geriBildirimler = [];

  @override
  Future<AsistanYanitModel> asistanaDetayliSor({
    required String message,
    required List<SohbetMesajiModel> history,
    String? clientContext,
  }) async {
    gonderilenMesajlar.add(message);
    gonderilenGecmisler.add(List<SohbetMesajiModel>.from(history));
    if (siradakiHata != null) {
      final hata = siradakiHata!;
      siradakiHata = null;
      throw hata;
    }
    return siradakiYanit ??
        const AsistanYanitModel(
          answer: '150g tavuk göğsü ve yoğurt ile 45g protein alabilirsin.',
          suggestions: [
            'Alternatif bir akşam öğünü önerir misin?',
            'Son 7 gün protein ortalamam nasıl?',
          ],
          contextTags: ['Profil & Hedefler', 'Bugünkü Beslenme'],
          messageId: '11111111222222223333333344444444',
          quota: AsistanKotaModel(used: 3, limit: 80, remaining: 77),
          actions: [
            AsistanEylemKartiModel(
              ogunTipi: 'aksam',
              baslik: 'Yüksek Proteinli Akşam Tabağı',
              besinler: [
                AsistanOgunKalemiModel(
                  besinId: 42,
                  isim: 'Tavuk göğsü',
                  gram: 150,
                  kalori: 248,
                  protein: 46.5,
                  karbonhidrat: 0,
                  yag: 5.4,
                ),
              ],
              toplamKalori: 248,
              toplamProtein: 46.5,
              toplamKarbonhidrat: 0,
              toplamYag: 5.4,
            ),
          ],
        );
  }

  @override
  Future<bool> asistanGeriBildirimGonder({
    required String messageId,
    String? rating,
    String? reason,
    bool actionApplied = false,
  }) async {
    geriBildirimler.add({
      'messageId': messageId,
      'rating': rating,
      'reason': reason,
      'actionApplied': actionApplied,
    });
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AsistanYanitModel & SohbetMesajiModel', () {
    test('AsistanYanitModel eylem kartlarını, kotayı ve meta alanlarını ayrıştırır', () {
      final model = AsistanYanitModel.fromJson({
        'answer': '  Harika gidiyorsun!  ',
        'meta': {
          'truncated': true,
          'message_id': 'abcdef0123456789abcdef0123456789',
          'quota': {'used': 5, 'limit': 80, 'remaining': 75},
          'suggestions': ['Öneri 1', 'Öneri 2'],
          'context_tags': ['Profil & Hedefler', 'Öğün Kayıtları'],
          'actions': [
            {
              'type': 'ogun_ekle',
              'ogun_tipi': 'aksam',
              'baslik': 'Akşam Tabağı',
              'besinler': [
                {
                  'besin_id': 10,
                  'isim': 'Tavuk göğsü',
                  'gram': 150,
                  'kalori': 248,
                  'protein': 46.5,
                  'karbonhidrat': 0,
                  'yag': 5.4,
                },
              ],
              'toplam': {
                'kalori': 248,
                'protein': 46.5,
                'karbonhidrat': 0,
                'yag': 5.4,
              },
            },
          ],
        },
      });

      expect(model.answer, 'Harika gidiyorsun!');
      expect(model.truncated, isTrue);
      expect(model.messageId, 'abcdef0123456789abcdef0123456789');
      expect(model.quota?.remaining, 75);
      expect(model.suggestions, ['Öneri 1', 'Öneri 2']);
      expect(model.contextTags, ['Profil & Hedefler', 'Öğün Kayıtları']);
      expect(model.actions.length, 1);
      expect(model.actions.first.ogunEtiketi, 'Akşam Yemeği');
      expect(model.actions.first.toplamKalori, 248);
    });

    test('SohbetMesajiModel toStorageJson / fromStorageJson eylem kartları ve geri bildirimle çalışır', () {
      final orijinal = SohbetMesajiModel(
        text: 'Bugün 1800 kcal aldım.',
        role: SohbetMesajiRolu.asistan,
        timestamp: DateTime.utc(2026, 10, 25, 12, 30),
        includeInHistory: true,
        suggestions: const ['Akşama ne yesem?'],
        contextTags: const ['Bugünkü Beslenme'],
        messageId: 'abcdef0123456789abcdef0123456789',
        feedbackRating: 'up',
        actions: const [
          AsistanEylemKartiModel(
            ogunTipi: 'sabah',
            baslik: 'Kahvaltı Tabağı',
            besinler: [
              AsistanOgunKalemiModel(
                besinId: 1,
                isim: 'Yumurta',
                gram: 100,
                kalori: 155,
                protein: 13,
                karbonhidrat: 1.1,
                yag: 11,
              ),
            ],
            toplamKalori: 155,
            toplamProtein: 13,
            toplamKarbonhidrat: 1.1,
            toplamYag: 11,
            uygulandi: true,
          ),
        ],
      );

      final json = orijinal.toStorageJson();
      final geriYuklenen = SohbetMesajiModel.fromStorageJson(json);

      expect(geriYuklenen.text, orijinal.text);
      expect(geriYuklenen.role, SohbetMesajiRolu.asistan);
      expect(geriYuklenen.feedbackRating, 'up');
      expect(geriYuklenen.actions.single.uygulandi, isTrue);
      expect(geriYuklenen.actions.single.ogunEtiketi, 'Kahvaltı');
    });
  });

  group('AsistanDenetleyici', () {
    test('mesaj gönderir, eylem kartını ve kotayı kaydeder, geçmişi kalıcı tutar', () async {
      final sahteApi = _SahteAsistanApi();
      final denetleyici = AsistanDenetleyici(api: sahteApi);

      await denetleyici.sendMessage('Akşama ne yesem?');

      expect(denetleyici.state.isLoading, isFalse);
      expect(denetleyici.state.gunlukKota?.remaining, 77);
      expect(denetleyici.state.messages.length, 3);
      final sonMesaj = denetleyici.state.messages.last;
      expect(sonMesaj.isUser, isFalse);
      expect(sonMesaj.actions.length, 1);
      expect(sonMesaj.actions.first.uygulandi, isFalse);

      // Eylem kartını uygula
      final uygulandi = await denetleyici.eylemKartiniUygula(sonMesaj);
      expect(uygulandi, isTrue);
      expect(denetleyici.state.messages.last.actions.first.uygulandi, isTrue);
      expect(sahteApi.geriBildirimler.last['actionApplied'], isTrue);

      // Geri bildirim ver
      await denetleyici.geriBildirimVer(
        denetleyici.state.messages.last,
        'up',
      );
      expect(denetleyici.state.messages.last.feedbackRating, 'up');
      expect(sahteApi.geriBildirimler.last['rating'], 'up');
    });

    test('hata durumunda isError işaretler ve yenidenDene ile tek dokunuşta tekrar gönderir', () async {
      final sahteApi = _SahteAsistanApi()
        ..siradakiHata = 'AI cevabı şu anda alınamadı.';
      final denetleyici = AsistanDenetleyici(
        api: sahteApi,
        kaliciDepoKullan: false,
      );

      await denetleyici.sendMessage('Bugün kaç kalori aldım?');

      expect(denetleyici.state.messages.last.isError, isTrue);
      expect(
        denetleyici.state.messages.last.failedPrompt,
        'Bugün kaç kalori aldım?',
      );

      final hataBalonu = denetleyici.state.messages.last;
      await denetleyici.yenidenDene(hataBalonu);

      expect(denetleyici.state.messages.last.isError, isFalse);
      expect(denetleyici.state.messages.last.text, contains('150g tavuk'));
      expect(denetleyici.state.messages.length, 3);
    });

    test('sohbetiTemizle hem belleği hem kalıcı geçmişi sıfırlar', () async {
      final sahteApi = _SahteAsistanApi();
      final denetleyici = AsistanDenetleyici(api: sahteApi);

      await denetleyici.sendMessage('Selam koç');
      expect(denetleyici.state.messages.length, 3);

      await denetleyici.sohbetiTemizle();
      expect(denetleyici.state.messages.length, 1);
      expect(denetleyici.state.messages.first.isUser, isFalse);
    });
  });
}
