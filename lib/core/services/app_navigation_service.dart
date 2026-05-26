import 'package:flutter/foundation.dart';
import 'package:breakmate/core/services/storage_service.dart';

class AppNavigationService {
  final StorageService storageService;
  late final ValueNotifier<String> selectedSection;

  AppNavigationService(this.storageService) {
    final lastSection = storageService.getString('last_opened_section', defaultValue: 'General');
    selectedSection = ValueNotifier<String>(lastSection);
  }

  void openSection(String section) {
    selectedSection.value = section;
    storageService.setString('last_opened_section', section);
  }

  void dispose() {
    selectedSection.dispose();
  }
}
