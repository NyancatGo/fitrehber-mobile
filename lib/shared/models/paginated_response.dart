class PaginatedResponse<T> {
  final List<T> results;
  final int count;
  final String? next;
  final String? previous;

  const PaginatedResponse({
    required this.results,
    required this.count,
    this.next,
    this.previous,
  });

  bool get hasNext => next != null;

  factory PaginatedResponse.fromJson(
    dynamic data,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    if (data is List) {
      final results = data
          .map((item) => fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
      return PaginatedResponse<T>(results: results, count: results.length);
    }

    if (data is Map) {
      final rawResults = data['results'];
      final results = rawResults is List
          ? rawResults
                .map((item) => fromJson(Map<String, dynamic>.from(item as Map)))
                .toList()
          : <T>[];

      return PaginatedResponse<T>(
        results: results,
        count: _asInt(data['count']) ?? results.length,
        next: _asNullableString(data['next']),
        previous: _asNullableString(data['previous']),
      );
    }

    return PaginatedResponse<T>(results: const [], count: 0);
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}

String? _asNullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
