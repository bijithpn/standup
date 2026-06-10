class StorageIntegrityCheck {
  bool verifyIntegrity(Map<String, dynamic> data) {
    if (data.containsKey('stats') && data['stats'] is! Map) {
      return false; // Corrupt stats payload
    }
    return true;
  }

  Map<String, dynamic> restoreDefaults() {
    return {'schema_version': 2, 'companion_enabled': true, 'stats': {}};
  }
}
