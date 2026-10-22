import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:breakmate/features/settings/presentation/sections/breaks/break_appearance_settings.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:breakmate/core/services/storage_service.dart';

final sl = GetIt.instance;

class FakeStorageService implements StorageService {
  @override
  bool get isReady => true;
  @override
  bool get hasFailed => false;
  @override
  int getInt(String key, {int defaultValue = 0}) => defaultValue;
  @override
  String getString(String key, {String defaultValue = ''}) => defaultValue;
  @override
  bool getBool(String key, {bool defaultValue = false}) => defaultValue;
  @override
  double getDouble(String key, {double defaultValue = 0.0}) => defaultValue;
  @override
  Future<bool> setInt(String key, int value) async => true;
  @override
  Future<bool> setString(String key, String value) async => true;
  @override
  Future<bool> setBool(String key, bool value) async => true;
  @override
  Future<bool> setDouble(String key, double value) async => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeStatsService extends StatsService {
  FakeStatsService() : super(storage: FakeStorageService());

  int get todayBreakCount => 3;
}

class FakeBreakController extends ChangeNotifier implements BreakController {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      final ByteData? data = const StandardMessageCodec().encodeMessage(<String, Object>{});
      return data ?? ByteData(0);
    }
    final Uint8List transparentPng = Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
      0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
      0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ]);
    return ByteData.sublistView(transparentPng);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (key == 'AssetManifest.json') {
      return jsonEncode({});
    }
    return jsonEncode({});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sl.allowReassignment = true;
    sl.registerSingleton<StatsService>(FakeStatsService());
    sl.registerSingleton<BreakController>(FakeBreakController());
  });

  testWidgets('renders a live preview tile for every template without throwing', (
    tester,
  ) async {
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: TestAssetBundle(),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BreakAppearanceSettings(
                settings: const SettingsModel(),
                onSave: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(BreakAppearanceSettings), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Night Sky'),
      100.0,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.text('Night Sky'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
