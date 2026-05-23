import 'package:fitrehber_mobile/shared/models/sayfali_yanit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> fromJson(Map<String, dynamic> json) => json;

  test('sayfalı API yanıt bilgisini ayrıştırır', () {
    final response = SayfaliYanit<Map<String, dynamic>>.fromJson({
      'count': 42,
      'next': 'https://api.example.test/items/?page=2',
      'previous': null,
      'results': [
        {'id': 1},
        {'id': 2},
      ],
    }, fromJson);

    expect(response.sonuclar, hasLength(2));
    expect(response.toplam, 42);
    expect(response.sonrakiVarMi, isTrue);
    expect(response.onceki, isNull);
  });

  test('sayfasız liste yanıtını sarar', () {
    final response = SayfaliYanit<Map<String, dynamic>>.fromJson([
      {'id': 1},
    ], fromJson);

    expect(response.sonuclar, hasLength(1));
    expect(response.toplam, 1);
    expect(response.sonrakiVarMi, isFalse);
  });
}
