/// Platform channels hand back `Map<Object?, Object?>` at every level, and the
/// generated `fromJson` casts nested maps straight to `Map<String, dynamic>`,
/// which throws. This converts a decoded payload, recursively, into the types
/// those casts expect.
Map<String, dynamic> stringKeyedMap(Map<dynamic, dynamic> source) {
  return source.map<String, dynamic>(
    (key, value) =>
        MapEntry<String, dynamic>(key.toString(), _normalize(value)),
  );
}

dynamic _normalize(dynamic value) {
  if (value is Map) return stringKeyedMap(value);
  if (value is List) return value.map<dynamic>(_normalize).toList();
  return value;
}
