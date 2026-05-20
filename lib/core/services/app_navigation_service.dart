import 'package:flutter/foundation.dart';

class AppNavigationService {
  final ValueNotifier<String> selectedSection = ValueNotifier<String>('General');

  void openSection(String section) {
    selectedSection.value = section;
  }

  void dispose() {
    selectedSection.dispose();
  }
}
