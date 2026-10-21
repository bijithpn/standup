import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:breakmate/core/native/native_bridge.dart';
import 'package:breakmate/features/companion/behavior/cursor_feed.dart';

/// Counts how often the feed actually reaches the platform.
class _FakeBridge implements NativeBridgePlatform {
  ui.Offset cursor = ui.Offset.zero;
  int calls = 0;

  @override
  Future<ui.Offset> getCursorPosition() async {
    calls++;
    return cursor;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeBridge bridge;
  late CursorFeed feed;

  setUp(() {
    bridge = _FakeBridge();
    feed = CursorFeed(bridge: bridge);
  });

  tearDown(() async {
    await feed.dispose();
  });

  test('does not touch the platform until something is listening', () async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(bridge.calls, 0);
  });

  test('samples while a listener is attached', () async {
    final samples = <CursorSample>[];
    final subscription = feed.subscribe(samples.add);
    addTearDown(subscription.cancel);

    bridge.cursor = const ui.Offset(120, 90);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(samples, isNotEmpty);
    expect(samples.last.position, const ui.Offset(120, 90));
  });

  test('stops sampling once the last listener cancels', () async {
    final subscription = feed.subscribe((_) {});
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(bridge.calls, greaterThan(0));

    await subscription.cancel();
    final callsAtCancel = bridge.calls;

    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(
      bridge.calls,
      callsAtCancel,
      reason: 'an unwatched feed must cost nothing',
    );
  });

  test('keeps sampling while any listener remains', () async {
    final first = feed.subscribe((_) {});
    final second = feed.subscribe((_) {});

    await first.cancel();
    final callsAtCancel = bridge.calls;
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(bridge.calls, greaterThan(callsAtCancel));
    await second.cancel();
  });

  test('slows down when the cursor holds still', () async {
    final subscription = feed.subscribe((_) {});
    addTearDown(subscription.cancel);

    // Hold perfectly still long enough to cross the rest threshold.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    expect(feed.isResting, isTrue);

    final callsWhileResting = bridge.calls;
    await Future<void>.delayed(const Duration(milliseconds: 320));
    final restingRate = bridge.calls - callsWhileResting;

    // Two sampling periods at the resting interval is 2 calls; the active
    // interval would have made about 10.
    expect(restingRate, lessThan(6));
  });

  test('speeds back up as soon as the cursor moves', () async {
    final subscription = feed.subscribe((_) {});
    addTearDown(subscription.cancel);

    await Future<void>.delayed(const Duration(milliseconds: 900));
    expect(feed.isResting, isTrue);

    bridge.cursor = const ui.Offset(600, 400);
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(feed.isResting, isFalse);
    expect(feed.position, const ui.Offset(600, 400));
  });

  test('survives a platform that cannot report the cursor', () async {
    final failing = CursorFeed(bridge: _ThrowingBridge());
    addTearDown(failing.dispose);

    final subscription = failing.subscribe((_) {});
    addTearDown(subscription.cancel);

    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(failing.position, ui.Offset.zero);
  });
}

class _ThrowingBridge implements NativeBridgePlatform {
  @override
  Future<ui.Offset> getCursorPosition() async =>
      throw StateError('no cursor on this platform');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
