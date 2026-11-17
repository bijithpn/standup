import 'dart:async';

import 'package:breakmate/core/services/desktop_update_notifier.dart';
import 'package:breakmate/core/services/feed_update_checker.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

FeedUpdate release(int build) => FeedUpdate(
  build: build,
  version: '1.0.$build',
  notes: '',
  downloadUrl: Uri.parse('https://example.com/$build.exe'),
);

void main() {
  test(
    'deduplicates by build across restarts and permits a newer build',
    () async {
      var saved = 0;
      var count = 0;
      var update = release(51);
      DesktopUpdateNotifier create() => DesktopUpdateNotifier(
        check: () async => update,
        notify: (_) async {
          count++;
          return true;
        },
        readNotifiedBuild: () => saved,
        saveNotifiedBuild: (build) async {
          saved = build;
        },
      );
      final first = create();
      await first.checkNow();
      await first.checkNow();
      first.dispose();
      final restarted = create();
      await restarted.checkNow();
      expect(count, 1);
      update = release(52);
      await restarted.checkNow();
      expect(count, 2);
      expect(saved, 52);
      restarted.dispose();
    },
  );

  test(
    'disabled or failed notifications and offline checks can retry',
    () async {
      var saved = 0;
      var online = false;
      var allowed = false;
      final notifier = DesktopUpdateNotifier(
        check: () async {
          if (!online) throw Exception('offline');
          return release(51);
        },
        notify: (_) async => allowed,
        readNotifiedBuild: () => saved,
        saveNotifiedBuild: (build) async {
          saved = build;
        },
      );
      await notifier.checkNow();
      online = true;
      await notifier.checkNow();
      expect(saved, 0);
      allowed = true;
      await notifier.checkNow();
      expect(saved, 51);
      notifier.dispose();
    },
  );

  test('does not overlap checks or notify after disposal', () async {
    final pending = Completer<FeedUpdate?>();
    var checks = 0;
    var notifications = 0;
    final notifier = DesktopUpdateNotifier(
      check: () {
        checks++;
        return pending.future;
      },
      notify: (_) async {
        notifications++;
        return true;
      },
      readNotifiedBuild: () => 0,
      saveNotifiedBuild: (_) async {},
    );
    final checking = notifier.checkNow();
    await notifier.checkNow();
    expect(checks, 1);
    notifier.dispose();
    pending.complete(release(51));
    await checking;
    expect(notifications, 0);
  });

  test('checks after startup and periodically, then stops on disposal', () {
    fakeAsync((async) {
      var checks = 0;
      final notifier = DesktopUpdateNotifier(
        check: () async {
          checks++;
          return null;
        },
        notify: (_) async => true,
        readNotifiedBuild: () => 0,
        saveNotifiedBuild: (_) async {},
      );
      notifier.start();
      notifier.start();
      async.elapse(const Duration(seconds: 9));
      expect(checks, 0);
      async.elapse(const Duration(seconds: 1));
      expect(checks, 1);
      async.elapse(const Duration(hours: 6));
      expect(checks, 2);
      notifier.dispose();
      async.elapse(const Duration(hours: 12));
      expect(checks, 2);
    });
  });
}
