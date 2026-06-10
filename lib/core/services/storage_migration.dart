import 'package:breakmate/core/constants/app_constants.dart';

class StorageMigrationLayer {
  static const int currentSchemaVersion = 2;

  Future<void> migrateStorage(Map<String, dynamic> data) async {
    final int version = data['schema_version'] ?? 1;

    if (version < 2) {
      if (data.containsKey(AppConstants.legacyKeyCompanionCatTheme)) {
        data[AppConstants.keyCompanionPetTheme] =
            data[AppConstants.legacyKeyCompanionCatTheme];
        data.remove(AppConstants.legacyKeyCompanionCatTheme);
      }
      data['schema_version'] = 2;
    }
  }
}
