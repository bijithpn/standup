// Measures real frame times (build and GPU raster) for every break template.
//
// Run on a real window in profile mode, where timings are meaningful:
//
//   flutter run --profile -d macos --flavor dev -t tool/frame_times.dart
//
// Prints one `FT` line per template and exits. Not part of the shipped app.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/break_system/presentation/widgets/break_template_switcher.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get_it/get_it.dart';

/// `--dart-define=TEMPLATES=zen,iris_rest` measures only those.
const _only = String.fromEnvironment('TEMPLATES');

final List<String> _ids = _only.isEmpty
    ? _all
    : _all.where(_only.split(',').contains).toList();

const _all = [
  'activities',
  // 'companion' is skipped: its pet asks window_manager for window bounds,
  // which needs the main app's native window setup this harness lacks.
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

class _Storage implements StorageService {
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

class _Stats extends StatsService {
  _Stats() : super(storage: _Storage());
}

class _Controller extends ChangeNotifier implements BreakController {
  @override
  Future<void> completeCurrentBreak({bool lookedAway = false}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final sl = GetIt.instance;
  sl.registerSingleton<StatsService>(_Stats());
  sl.registerSingleton<BreakController>(_Controller());
  runApp(const _Harness());
}

class _Harness extends StatefulWidget {
  const _Harness();

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> with TickerProviderStateMixin {
  static const _warmUp = Duration(seconds: 1);
  static const _measure = Duration(seconds: 5);

  late final AnimationController _kenBurns = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 15),
  )..repeat(reverse: true);

  int _index = 0;
  int _remaining = 55;
  final List<ui.FrameTiming> _frames = [];
  bool _measuring = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback((timings) {
      if (_measuring) _frames.addAll(timings);
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _remaining = (_remaining - 1).clamp(1, 60));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _runNext());
  }

  Future<void> _runNext() async {
    if (_index >= _ids.length) {
      stdout.writeln('FT-DONE');
      await stdout.flush();
      exit(0);
    }
    _frames.clear();
    await Future<void>.delayed(_warmUp);
    _measuring = true;
    await Future<void>.delayed(_measure);
    _measuring = false;
    // Timings arrive a few frames late.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _report(_ids[_index]);
    setState(() {
      _index++;
      _remaining = 55;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _runNext());
  }

  void _report(String id) {
    double ms(Duration d) => d.inMicroseconds / 1000;
    final build = _frames.map((f) => ms(f.buildDuration)).toList()..sort();
    final raster = _frames.map((f) => ms(f.rasterDuration)).toList()..sort();
    if (raster.isEmpty) {
      stdout.writeln('FT $id no-frames');
      return;
    }
    double avg(List<double> v) => v.reduce((a, b) => a + b) / v.length;
    double p95(List<double> v) =>
        v[(v.length * 0.95).floor().clamp(0, v.length - 1)];
    final over = raster.where((r) => r > 8.3).length;
    stdout.writeln(
      'FT ${id.padRight(13)} frames=${raster.length.toString().padLeft(3)} '
      'build avg=${avg(build).toStringAsFixed(2)} p95=${p95(build).toStringAsFixed(2)} '
      'raster avg=${avg(raster).toStringAsFixed(2)} p95=${p95(raster).toStringAsFixed(2)} '
      'max=${raster.last.toStringAsFixed(2)} over8.3ms=$over',
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    _kenBurns.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = _ids[_index.clamp(0, _ids.length - 1)];
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Inter'),
      home: Scaffold(
        body: BreakTemplateSwitcher(
          key: ValueKey(id),
          breakTemplate: id,
          breakInfo: const BreakModel(
            type: BreakType.short,
            durationSeconds: 60,
            title: 'Rest Your Eyes',
            tip: 'Look 20 feet away for 20 seconds.',
          ),
          settings: const SettingsModel(),
          remaining: _remaining,
          total: 60,
          onSkip: null,
          kenBurnsController: _kenBurns,
        ),
      ),
    );
  }
}
