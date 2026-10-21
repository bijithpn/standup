import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import 'package:breakmate/features/companion/render/avatar_artwork_recipe.dart';
import 'package:breakmate/features/companion/render/avatar_svg_preparer.dart';

/// A single long-lived isolate that compiles avatar artwork off the UI thread.
///
/// `flutter_svg` already moves this work off-thread, but it does so with
/// `compute()`, which spawns and tears down an isolate for *every* compile. The
/// customizer paints 129 breed tiles at once, so that alone is 129 isolate
/// spawns competing with the frame loop. One worker, kept warm between
/// requests and retired when idle, removes that cost entirely.
class AvatarArtworkWorker {
  AvatarArtworkWorker._();

  static final AvatarArtworkWorker instance = AvatarArtworkWorker._();

  /// How long the worker sticks around with nothing to do before shutting down.
  static const Duration idleTimeout = Duration(seconds: 30);

  Isolate? _isolate;
  SendPort? _commands;
  ReceivePort? _responses;
  Completer<void>? _starting;
  Timer? _idleTimer;

  int _nextRequestId = 0;
  final Map<int, Completer<Uint8List>> _pending = <int, Completer<Uint8List>>{};

  /// True while the worker isolate is alive.
  @visibleForTesting
  bool get isRunning => _commands != null;

  /// Compiles [rawSvg] according to [recipe], off the UI thread.
  ///
  /// Falls back to compiling inline if the isolate cannot be started — a slow
  /// frame beats a companion that never appears.
  Future<Uint8List> compile(
    AvatarArtworkRecipe recipe,
    Uint8List rawSvg,
  ) async {
    try {
      await _ensureStarted();
    } catch (_) {
      return compileAvatarArtwork(recipe, utf8.decode(rawSvg));
    }

    final commands = _commands;
    if (commands == null) {
      return compileAvatarArtwork(recipe, utf8.decode(rawSvg));
    }

    _idleTimer?.cancel();
    final id = _nextRequestId++;
    final completer = Completer<Uint8List>();
    _pending[id] = completer;

    commands.send(<Object?>[
      id,
      recipe,
      TransferableTypedData.fromList(<Uint8List>[rawSvg]),
    ]);

    try {
      return await completer.future;
    } finally {
      _scheduleIdleShutdown();
    }
  }

  Future<void> _ensureStarted() {
    if (_commands != null) return Future<void>.value();
    final starting = _starting;
    if (starting != null) return starting.future;

    final completer = Completer<void>();
    _starting = completer;

    unawaited(() async {
      final responses = ReceivePort();
      try {
        _isolate = await Isolate.spawn(
          _workerEntry,
          responses.sendPort,
          debugName: 'avatar-artwork-worker',
          errorsAreFatal: false,
        );
      } catch (error, stack) {
        responses.close();
        _starting = null;
        completer.completeError(error, stack);
        return;
      }

      _responses = responses;
      responses.listen(_handleResponse);

      // The worker's first message is the port to send requests on.
      // `_handleResponse` completes `_starting` once it arrives.
    }());

    return completer.future;
  }

  void _handleResponse(dynamic message) {
    if (message is SendPort) {
      _commands = message;
      _starting?.complete();
      _starting = null;
      _scheduleIdleShutdown();
      return;
    }

    if (message is! List || message.length < 3) return;
    final id = message[0] as int;
    final completer = _pending.remove(id);
    if (completer == null) return;

    final error = message[2];
    if (error != null) {
      completer.completeError(
        StateError('Avatar artwork compile failed: $error'),
      );
      return;
    }
    completer.complete(
      (message[1] as TransferableTypedData).materialize().asUint8List(),
    );
  }

  void _scheduleIdleShutdown() {
    _idleTimer?.cancel();
    if (_pending.isNotEmpty) return;
    _idleTimer = Timer(idleTimeout, () {
      if (_pending.isEmpty) shutdown();
    });
  }

  /// Retires the worker. Safe to call at any time; the next [compile] restarts
  /// it.
  void shutdown() {
    _idleTimer?.cancel();
    _idleTimer = null;
    _commands = null;
    _responses?.close();
    _responses = null;
    _isolate?.kill(priority: Isolate.beforeNextEvent);
    _isolate = null;

    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Avatar artwork worker shut down'));
      }
    }
    _pending.clear();
  }
}

/// Entry point of the worker isolate: compile requests in, buffers out.
void _workerEntry(SendPort responses) {
  final commands = ReceivePort();
  responses.send(commands.sendPort);

  commands.listen((dynamic message) {
    if (message is! List || message.length < 3) return;
    final id = message[0] as int;
    final recipe = message[1] as AvatarArtworkRecipe;
    final rawSvg = (message[2] as TransferableTypedData).materialize();

    try {
      final compiled = compileAvatarArtwork(
        recipe,
        utf8.decode(rawSvg.asUint8List()),
      );
      responses.send(<Object?>[
        id,
        TransferableTypedData.fromList(<Uint8List>[compiled]),
        null,
      ]);
    } catch (error) {
      responses.send(<Object?>[id, null, error.toString()]);
    }
  });
}
