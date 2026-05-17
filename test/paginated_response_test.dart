import 'package:fitrehber_mobile/shared/models/paginated_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> fromJson(Map<String, dynamic> json) => json;

  test('parses paginated API response metadata', () {
    final response = PaginatedResponse<Map<String, dynamic>>.fromJson({
      'count': 42,
      'next': 'https://api.example.test/items/?page=2',
      'previous': null,
      'results': [
        {'id': 1},
        {'id': 2},
      ],
    }, fromJson);

    expect(response.results, hasLength(2));
    expect(response.count, 42);
    expect(response.hasNext, isTrue);
    expect(response.previous, isNull);
  });

  test('wraps non-paginated list responses', () {
    final response = PaginatedResponse<Map<String, dynamic>>.fromJson([
      {'id': 1},
    ], fromJson);

    expect(response.results, hasLength(1));
    expect(response.count, 1);
    expect(response.hasNext, isFalse);
  });
}
