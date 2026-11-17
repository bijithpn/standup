import 'package:audioplayers/audioplayers.dart';
import 'package:breakmate/core/services/soundscape_service.dart';
import 'package:breakmate/features/break_overlay/wellness/wellness_models.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

class FakePlayer implements AudioPlayer {
  double vol = 1;
  bool playing = false;
  bool paused = false;
  bool disposed = false;
  int plays = 0;
  ReleaseMode? loopMode;
  Source? src;

  @override
  Future<void> setReleaseMode(ReleaseMode m) async => loopMode = m;
  @override
  Future<void> setVolume(double v) async => vol = v;
  @override
  Future<void> play(
    Source s, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    src = s;
    plays++;
    playing = true;
    paused = false;
    if (volume != null) vol = volume;
  }

  @override
  Future<void> pause() async => paused = true;
  @override
  Future<void> resume() async => paused = false;
  @override
  Future<void> stop() async {
    playing = false;
    paused = false;
  }

  @override
  Future<void> dispose() async => disposed = true;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late List<FakePlayer> players;
  late SoundscapeService svc;

  void run(void Function(FakeAsync) body) => fakeAsync((a) {
    players = [];
    svc = SoundscapeService(
      playerFactory: () {
        final p = FakePlayer();
        players.add(p);
        return p;
      },
    );
    body(a);
  });

  test('fade-in reaches target volume on one looping player', () {
    run((a) {
      svc.start(Soundscape.rain, 0.6);
      a.flushMicrotasks();
      expect(players, hasLength(1));
      expect(players.single.loopMode, ReleaseMode.loop);
      expect(players.single.vol, 0);
      a.elapse(const Duration(milliseconds: 700));
      expect(players.single.vol, inExclusiveRange(0, 0.6));
      a.elapse(const Duration(seconds: 1));
      expect(players.single.vol, closeTo(0.6, 1e-9));
      expect(svc.isPlaying, isTrue);
    });
  });

  test('stop fades out then stops; second stop is a no-op', () {
    run((a) {
      svc.start(Soundscape.ocean, 0.5);
      a.elapse(const Duration(seconds: 2));
      svc.stop();
      a.elapse(const Duration(milliseconds: 600));
      expect(players.single.playing, isTrue);
      expect(players.single.vol, lessThan(0.5));
      a.elapse(const Duration(seconds: 1));
      expect(players.single.playing, isFalse);
      expect(players.single.vol, 0);
      svc.stop();
      a.flushMicrotasks();
      expect(svc.isPlaying, isFalse);
    });
  });

  test('immediate stop halts at once', () {
    run((a) {
      svc.start(Soundscape.forest, 0.5);
      a.elapse(const Duration(seconds: 2));
      svc.stop(immediate: true);
      a.flushMicrotasks();
      expect(players.single.playing, isFalse);
    });
  });

  test('rapid start/stop keeps one player and ends stopped', () {
    run((a) {
      svc.start(Soundscape.rain, 0.5);
      svc.stop();
      svc.start(Soundscape.forest, 0.5);
      svc.stop(immediate: true);
      svc.start(Soundscape.ocean, 0.5);
      a.elapse(const Duration(milliseconds: 300));
      svc.stop();
      svc.start(Soundscape.forest, 0.5);
      svc.stop();
      a.elapse(const Duration(seconds: 5));
      expect(players, hasLength(1));
      expect(players.single.playing, isFalse);
      expect(svc.isPlaying, isFalse);
    });
  });

  test('switching scapes swaps the asset on the same player', () {
    run((a) {
      svc.start(Soundscape.rain, 0.5);
      a.elapse(const Duration(seconds: 2));
      svc.start(Soundscape.ocean, 0.5);
      a.elapse(const Duration(seconds: 2));
      expect(players, hasLength(1));
      expect(
        (players.single.src as AssetSource).path,
        'audio/soundscapes/ocean.mp3',
      );
      expect(players.single.vol, closeTo(0.5, 1e-9));
    });
  });

  test('suspend pauses without reset, resume continues', () {
    run((a) {
      svc.start(Soundscape.rain, 0.5);
      a.elapse(const Duration(seconds: 2));
      svc.suspend();
      a.flushMicrotasks();
      expect(players.single.paused, isTrue);
      expect(svc.isPlaying, isFalse);
      expect(players.single.plays, 1);
      svc.resume();
      a.elapse(const Duration(seconds: 2));
      expect(players.single.paused, isFalse);
      expect(players.single.plays, 1);
      expect(svc.isPlaying, isTrue);
      expect(players.single.vol, closeTo(0.5, 1e-9));
    });
  });

  test('muted start and silence are no-ops', () {
    run((a) {
      svc.start(Soundscape.rain, 0.5, muted: true);
      svc.start(Soundscape.silence, 0.5);
      a.flushMicrotasks();
      expect(players, isEmpty);
      expect(svc.isPlaying, isFalse);
    });
  });

  test('silence stops a playing scape', () {
    run((a) {
      svc.start(Soundscape.rain, 0.5);
      a.elapse(const Duration(seconds: 2));
      svc.start(Soundscape.silence, 0.5);
      a.elapse(const Duration(seconds: 2));
      expect(players.single.playing, isFalse);
    });
  });

  test('dispose cancels the fade timer and disposes the player', () {
    run((a) {
      svc.start(Soundscape.rain, 0.5);
      a.elapse(const Duration(milliseconds: 300));
      expect(a.pendingTimers, isNotEmpty);
      svc.dispose();
      a.flushMicrotasks();
      expect(a.pendingTimers, isEmpty);
      expect(players.single.disposed, isTrue);
    });
  });
}
