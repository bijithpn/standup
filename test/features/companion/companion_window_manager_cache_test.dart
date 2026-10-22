import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:breakmate/features/companion/domain/behavior_engine_models.dart';
import 'package:breakmate/features/companion/services/companion_window_controller.dart';
import 'package:breakmate/features/companion/services/companion_window_manager.dart';
import 'package:breakmate/features/companion/services/display_manager.dart';

class _CountingDisplays implements DisplayManager {
  _CountingDisplays(this.height);

  double height;
  int enumerations = 0;

  @override
  Future<List<DisplayBounds>> enumerateDisplays() async {
    enumerations++;
    return <DisplayBounds>[
      DisplayBounds(
        id: 'primary',
        rect: Rect.fromLTWH(0, 0, 1440, height),
        dpiScale: 2,
        isPrimary: true,
      ),
    ];
  }

  @override
  List<DisplayBounds> get displays => const <DisplayBounds>[];
  @override
  Rect get unionBounds => Rect.zero;
  @override
  Offset nearestDisplayPoint(Offset outside) => outside;
  @override
  bool areAdjacent(DisplayBounds a, DisplayBounds b) => false;
  @override
  void poll() {}
  @override
  void onDisplayChanged(List<DisplayBounds> newBounds) {}
}

class _FakeController extends CompanionWindowController {
  _FakeController();

  /// AppKit coordinates: origin bottom-left of the primary display.
  Map<String, dynamic> next = <String, dynamic>{
    'x': 100.0,
    'y': 200.0,
    'width': 280.0,
    'height': 320.0,
  };

  @override
  Future<Map<String, dynamic>> getPosition() async => next;
}

void main() {
  // The coordinate flip only exists on macOS.
  final isMac = Platform.isMacOS;

  test(
    'reading the window position does not re-enumerate displays every time',
    () async {
      final displays = _CountingDisplays(900);
      final manager = CompanionWindowManager(
        windowController: _FakeController(),
        displayManager: displays,
      );

      for (var i = 0; i < 20; i++) {
        await manager.getPosition();
      }

      expect(displays.enumerations, 1);
    },
    skip: !isMac,
  );

  test(
    'converts AppKit coordinates using the primary display height',
    () async {
      final displays = _CountingDisplays(900);
      final manager = CompanionWindowManager(
        windowController: _FakeController(),
        displayManager: displays,
      );

      final position = await manager.getPosition();

      // top = primaryHeight - bottomY - windowHeight
      expect(position, const Offset(100, 900 - 200 - 320));
    },
    skip: !isMac,
  );

  test('a display change invalidates the cached height', () async {
    final displays = _CountingDisplays(900);
    final manager = CompanionWindowManager(
      windowController: _FakeController(),
      displayManager: displays,
    );
    await manager.getPosition();

    // The user swaps to a taller primary display.
    displays.height = 1200;
    manager.invalidateDisplayCache();
    final position = await manager.getPosition();

    expect(displays.enumerations, 2);
    expect(position.dy, 1200 - 200 - 320);
  }, skip: !isMac);

  test(
    'a window on a display above the primary keeps a negative top',
    () async {
      final displays = _CountingDisplays(900);
      final controller = _FakeController()
        // Bottom edge 1200pt above the primary's bottom: well above its top.
        ..next = <String, dynamic>{
          'x': -300.0,
          'y': 1200.0,
          'width': 280.0,
          'height': 320.0,
        };
      final manager = CompanionWindowManager(
        windowController: controller,
        displayManager: displays,
      );

      final position = await manager.getPosition();

      expect(position, const Offset(-300, 900 - 1200 - 320));
      expect(position.dy, lessThan(0));
    },
    skip: !isMac,
  );
}
