import 'dart:convert';
import 'dart:io';

import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/break_system/presentation/widgets/break_template_switcher.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

/// Every template identifier, in the order of the design spec.
const allBreakTemplateIds = [
  'activities',
  'companion',
  'floating',
  'minimal',
  'zen',
  'breathe_line',
  'one_word',
  'pulse_dot',
  'focus_orb',
  'wave_calm',
  'ring_only',
  'soft_arc',
  'iris_rest',
  'quiet_pill',
  'classic',
  'hud',
  'clock_face',
  'mono_time',
  'time_slice',
  'day_stack',
  'split_view',
  'step_guide',
  'haiku_card',
  'warm_amber',
  'open_field',
  'dusk_glow',
  'paper_light',
  'night_sky',
  'wind_down',
];

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
}

class FakeBreakController extends ChangeNotifier implements BreakController {
  int completed = 0;
  @override
  Future<void> completeCurrentBreak() async => completed++;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Asset bundle that answers every image request with a 1x1 PNG so
/// `Image.asset` never throws in tests.
class TestAssetBundle extends CachingAssetBundle {
  static final Uint8List _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  );

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage(<String, Object>{})!;
    }
    return ByteData.sublistView(_png);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async => '{}';
}

/// Registers the fakes templates reach through `sl<...>()` and loads Inter so
/// goldens show real glyphs instead of Ahem boxes.
Future<void> setUpBreakTestEnvironment() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final sl = GetIt.instance;
  sl.allowReassignment = true;
  sl.registerSingleton<StatsService>(FakeStatsService());
  sl.registerSingleton<BreakController>(FakeBreakController());
  await loadInter();
}

Future<void> loadInter() async {
  final loader = FontLoader('Inter');
  for (final f in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final bytes = File('assets/fonts/Inter/Inter-$f.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
  // System monospace faces do not exist under flutter test; alias them to a
  // real font so goldens show glyphs instead of Ahem boxes.
  final roboto = File(
    _materialIconsPath().replaceFirst(
      'MaterialIcons-Regular.otf',
      'Roboto-Regular.ttf',
    ),
  );
  if (roboto.existsSync()) {
    for (final family in ['Menlo', 'Courier', 'Georgia']) {
      final l = FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(roboto.readAsBytesSync())));
      await l.load();
    }
  }
  await _loadIconFont('MaterialIcons', _materialIconsPath());
  await _loadIconFont(
    'packages/lucide_icons_flutter/Lucide',
    'packages/lucide_icons_flutter/assets/lucide.ttf',
  );
}

String _materialIconsPath() {
  final root =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  return '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
}

Future<void> _loadIconFont(String family, String path) async {
  try {
    final file = File(path);
    final ByteData data;
    if (file.existsSync()) {
      data = ByteData.sublistView(file.readAsBytesSync());
    } else {
      data = await rootBundle.load(path);
    }
    final loader = FontLoader(family)..addFont(Future.value(data));
    await loader.load();
  } catch (_) {
    // Icons stay as boxes in goldens; layout is unaffected.
  }
}

const shortBreak = BreakModel(
  type: BreakType.short,
  durationSeconds: 60,
  title: 'Rest Your Eyes',
  tip: 'Look 20 feet away for 20 seconds.',
);

const longBreak = BreakModel(
  type: BreakType.long,
  durationSeconds: 300,
  title: 'Take a Break',
  tip: 'Stand up. Roll your shoulders. Take three slow breaths.',
);

/// Pumps [templateId] through [BreakTemplateSwitcher] at [size].
Future<void> pumpBreakTemplate(
  WidgetTester tester,
  String templateId, {
  Size size = const Size(1280, 800),
  bool dark = true,
  bool reducedMotion = false,
  bool preview = false,
  BreakModel breakInfo = shortBreak,
  SettingsModel settings = const SettingsModel(),
  int remaining = 39,
  int total = 60,
  VoidCallback? onSkip,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  late AnimationController kenBurns;
  Widget app = DefaultAssetBundle(
    bundle: TestAssetBundle(),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: dark ? Brightness.dark : Brightness.light,
        fontFamily: 'Inter',
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
        child: child!,
      ),
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, _) {
            kenBurns = AnimationController(
              vsync: tester,
              duration: const Duration(seconds: 10),
            );
            addTearDown(kenBurns.dispose);
            Widget w = BreakTemplateSwitcher(
              breakTemplate: templateId,
              breakInfo: breakInfo,
              settings: settings,
              remaining: remaining,
              total: total,
              onSkip: onSkip,
              kenBurnsController: kenBurns,
            );
            if (preview) w = BreakPreviewScope(child: w);
            return w;
          },
        ),
      ),
    ),
  );
  await tester.pumpWidget(app);
  await tester.pump(const Duration(seconds: 2));
}
