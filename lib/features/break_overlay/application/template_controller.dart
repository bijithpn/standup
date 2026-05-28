import 'package:flutter/foundation.dart';
import '../domain/template_model.dart';

class TemplateController extends ChangeNotifier {
  TemplateModel? _selectedTemplate;
  TemplateModel? get selectedTemplate => _selectedTemplate;

  void selectTemplate(TemplateModel template) {
    _selectedTemplate = template;
    notifyListeners();
  }
}
