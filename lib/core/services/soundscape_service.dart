import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'package:breakmate/features/break_overlay/wellness/wellness_models.dart';

/// Optional ambient loop for breaks, backed by a single lazily created player.
///
/// Audio is off by default: nothing plays until the caller explicitly calls
/// [start] with a non-silence scape (the caller reads the user's setting).
class SoundscapeService {
  SoundscapeService({AudioPlayer Function()? playerFactory})
    : _factory = playerFactory ?? AudioPlayer.new;

  static const _tick = Duration(milliseconds: 50);
  static const _fadeInMs = 1500;
  static const _fadeOutMs = 1200;

  final AudioPlayer Function() _factory;
  AudioPlayer? _player;
  Timer? _fade;
  double _level = 0;
  double _volume = 0;
  bool _active = false;
  bool _suspended = false;
  Soundscape _current = Soundscape.silence;
  int _gen = 0;

  bool get isPlaying => _active && !_suspended;

  /// Ignored when [muted] (quiet mode). [Soundscape.silence] stops playback.
  Future<void> start(Soundscape s, double volume, {bool muted = false}) async {
    if (muted) return;
    if (s == Soundscape.silence) return stop();
    _volume = volume.clamp(0.0, 1.0);
    if (_active && _current == s) {
      if (!_suspended) _fadeTo(_volume, _fadeInMs);
      return;
    }
    final gen = ++_gen;
    _fade?.cancel();
    _current = s;
    _active = true;
    _suspended = false;
    _level = 0;
    try {
      final p = await _ensure();
      if (gen != _gen) return;
      await p.stop();
      if (gen != _gen) return;
      await p.play(AssetSource('audio/soundscapes/${s.name}.mp3'), volume: 0);
      if (gen != _gen) return;
      if (_suspended) {
        await p.pause();
      } else {
        _fadeTo(_volume, _fadeInMs);
      }
    } catch (e) {
      debugPrint('Soundscape start failed: $e');
      if (gen == _gen) _active = false;
    }
  }

  Future<void> stop({bool immediate = false}) async {
    if (!_active) return;
    final wasSuspended = _suspended;
    _active = false;
    _suspended = false;
    final gen = ++_gen;
    if (immediate || wasSuspended || _level == 0) {
      _fade?.cancel();
      return _halt();
    }
    _fadeTo(0, _fadeOutMs, () {
      if (gen == _gen) _halt();
    });
  }

  /// Pauses without resetting position (sleep/lock).
  void suspend() {
    if (!_active || _suspended) return;
    _suspended = true;
    _fade?.cancel();
    _player?.pause();
  }

  void resume() {
    if (!_active || !_suspended) return;
    _suspended = false;
    _player?.resume();
    _fadeTo(_volume, _fadeInMs);
  }

  void setVolume(double v) {
    _volume = v.clamp(0.0, 1.0);
    if (isPlaying) _fadeTo(_volume, 100);
  }

  Future<void> dispose() async {
    _gen++;
    _fade?.cancel();
    _active = false;
    final p = _player;
    _player = null;
    await p?.dispose();
  }

  Future<AudioPlayer> _ensure() async {
    final p = _player ??= _factory();
    await p.setReleaseMode(ReleaseMode.loop);
    return p;
  }

  Future<void> _halt() async {
    _level = 0;
    _fade = null;
    await _player?.stop();
  }

  void _fadeTo(double target, int ms, [VoidCallback? done]) {
    _fade?.cancel();
    final steps = (ms / _tick.inMilliseconds).ceil();
    final delta = (target - _level) / steps;
    var n = 0;
    _fade = Timer.periodic(_tick, (t) {
      if (++n >= steps) {
        t.cancel();
        _fade = null;
        _level = target;
        _player?.setVolume(_level);
        done?.call();
      } else {
        _level += delta;
        _player?.setVolume(_level);
      }
    });
  }
}
