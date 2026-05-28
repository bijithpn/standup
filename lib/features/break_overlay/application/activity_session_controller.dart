import 'package:flutter/foundation.dart';
import '../domain/activity_model.dart';

class ActivitySessionController extends ChangeNotifier {
  ActivityModel? _currentActivity;
  ActivityModel? get currentActivity => _currentActivity;

  void startActivity(ActivityModel activity) {
    _currentActivity = activity;
    notifyListeners();
  }

  void endActivity() {
    _currentActivity = null;
    notifyListeners();
  }
}
