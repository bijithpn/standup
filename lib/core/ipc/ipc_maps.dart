/// Platform channels deliver `Map<dynamic, dynamic>`; this deep-converts them to `Map<String, dynamic>` for JSON/freezed parsing.
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
