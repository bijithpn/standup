import 'package:shared_preferences/shared_preferences.dart';
import 'package:breakmate/core/errors/app_exception.dart';
import 'package:breakmate/core/errors/error_handler.dart';

class StorageService {
  late SharedPreferences _prefs;
  final ErrorHandler _errorHandler = ErrorHandler();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<bool> setInt(String key, int value) async {
    return await _errorHandler.guard(
          action: () => _prefs.setInt(key, value),
          errorType: ErrorType.storage,
          fallback: false,
        ) ??
        false;
  }

  int getInt(String key, {int defaultValue = 0}) {
    return _prefs.getInt(key) ?? defaultValue;
  }

  Future<bool> setBool(String key, bool value) async {
    return await _errorHandler.guard(
          action: () => _prefs.setBool(key, value),
          errorType: ErrorType.storage,
          fallback: false,
        ) ??
        false;
  }

  bool getBool(String key, {bool defaultValue = false}) {
    return _prefs.getBool(key) ?? defaultValue;
  }

  Future<bool> setString(String key, String value) async {
    return await _errorHandler.guard(
          action: () => _prefs.setString(key, value),
          errorType: ErrorType.storage,
          fallback: false,
        ) ??
        false;
  }

  String getString(String key, {String defaultValue = ''}) {
    return _prefs.getString(key) ?? defaultValue;
  }

  Future<bool> setDouble(String key, double value) async {
    return await _errorHandler.guard(
          action: () => _prefs.setDouble(key, value),
          errorType: ErrorType.storage,
          fallback: false,
        ) ??
        false;
  }

  double getDouble(String key, {double defaultValue = 0.0}) {
    return _prefs.getDouble(key) ?? defaultValue;
  }
}
