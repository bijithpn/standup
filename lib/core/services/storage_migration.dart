class StorageMigrationLayer {
  static const int currentSchemaVersion = 2;

  Future<void> migrateStorage(Map<String, dynamic> data) async {
    final int version = data['schema_version'] ?? 1;
    
    if (version < 2) {
      // Migrate old keys such as companion_cat_theme to pet-neutral names
      if (data.containsKey('companion_cat_theme')) {
        data['companion_pet_theme'] = data['companion_cat_theme'];
        data.remove('companion_cat_theme');
      }
      data['schema_version'] = 2;
    }
  }
}
