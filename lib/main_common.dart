import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart'
    show SentryFlutter, SentryWidget;
import 'package:window_manager/window_manager.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';

import 'app/app.dart';
import 'app/bootstrapping/service_bootstrapper.dart';
import 'app/bootstrapping/ipc_coordinator.dart';
import 'core/core.dart';
import 'features/features.dart';
import 'shared/shared.dart';

void _setupGlobalErrors() {
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('=== FLUTTER ERROR ===');
    debugPrint(details.exceptionAsString());
    debugPrint(details.stack?.toString());

    final exceptionStr = details.exceptionAsString();
    final isHardwareKeyboardAssert =
        exceptionStr.contains('HardwareKeyboard') ||
        exceptionStr.contains('_pressedKeys.containsKey');

    if (!details.silent && !isHardwareKeyboardAssert) {
      ErrorToastService.showError('Oops! An internal error occurred.');
    }
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('=== ASYNC DART ERROR ===');
    debugPrint(error.toString());
    debugPrint(stack.toString());
    ErrorToastService.showError('Oops! An action failed. Please try again.');
    return true;
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (StandaloneBreakOverlay.onErrorCallbacks.isNotEmpty) {
      for (final callback in List.from(
        StandaloneBreakOverlay.onErrorCallbacks,
      )) {
        try {
          callback(details);
        } catch (e, st) {
          ErrorHandler().handleError(e, st);
        }
      }
      return const Material(color: Color(0xFF0A0A0F), child: SizedBox.shrink());
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: const Color(0xFF161616),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Oops! Something went wrong.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'An unexpected error occurred. We have logged the details.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontFamily: 'Inter',
                  ),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        details.exceptionAsString(),
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  };
}

ServerSocket? _globalSingleInstanceServer;

Future<void> _gracefulShutdown(ServerSocket? serverSocket) async {
  debugPrint('[Shutdown] Starting graceful shutdown...');

  try {
    if (sl.isRegistered<SettingsRepository>()) {
      final settingsRepo = sl<SettingsRepository>();
      await settingsRepo.save(settingsRepo.currentSettings);
      debugPrint('[Shutdown] Settings saved & flushed.');
    }
  } catch (e) {
    debugPrint('[Shutdown] Error saving settings: $e');
  }

  try {
    if (sl.isRegistered<OverlayWindowService>()) {
      await sl<OverlayWindowService>().reset();
      debugPrint('[Shutdown] OverlayWindowService reset complete.');
    }
  } catch (e) {
    debugPrint('[Shutdown] Error resetting OverlayWindowService: $e');
  }

  try {
    await NativeBridge.hideCompanion();
    debugPrint('[Shutdown] Companion hidden.');
  } catch (e) {
    debugPrint('[Shutdown] Error hiding companion: $e');
  }

  try {
    if (sl.isRegistered<TimerEngine>()) {
      sl<TimerEngine>().dispose();
      debugPrint('[Shutdown] TimerEngine disposed.');
    }
  } catch (e) {
    debugPrint('[Shutdown] Error disposing TimerEngine: $e');
  }

  try {
    if (sl.isRegistered<TimerOrchestrator>()) {
      sl<TimerOrchestrator>().shutdown();
      debugPrint('[Shutdown] TimerOrchestrator shutdown complete.');
    }
  } catch (e) {
    debugPrint('[Shutdown] Error shutting down TimerOrchestrator: $e');
  }

  try {
    if (sl.isRegistered<SmartDetectionService>()) {
      sl<SmartDetectionService>().dispose();
      debugPrint('[Shutdown] SmartDetectionService disposed.');
    }
  } catch (e) {
    debugPrint('[Shutdown] Error disposing SmartDetectionService: $e');
  }

  try {
    if (serverSocket != null) {
      await serverSocket.close();
      debugPrint('[Shutdown] Single-instance server socket closed.');
    }
  } catch (e) {
    debugPrint('[Shutdown] Error closing server socket: $e');
  }

  try {
    if (sl.isRegistered<StorageService>()) {
      sl<StorageService>().close();
      debugPrint('[Shutdown] StorageService closed cleanly.');
    }
  } catch (e) {
    debugPrint('[Shutdown] Error closing StorageService: $e');
  }

  debugPrint('[Shutdown] Graceful shutdown complete. Exiting.');
  exit(0);
}

Future<void> gracefulShutdown() async {
  await _gracefulShutdown(_globalSingleInstanceServer);
}

void mainCommon(FlavorConfig config) async {
  final isolateName = Isolate.current.debugName ?? '';
  final isMainIsolate =
      !isolateName.toLowerCase().contains('overlay') &&
      !isolateName.toLowerCase().contains('companion');

  debugPrint('[Main] Isolate name: "$isolateName"');
  if (isolateName.toLowerCase().contains('overlaymain')) {
    overlayMain();
    return;
  } else if (isolateName.toLowerCase().contains('companionmain')) {
    companionMain();
    return;
  }

  runZonedGuarded(
    () async {
      try {
        final startupT0 = DateTime.now();
        void logStartup(String label) {
          if (kDebugMode) {
            final ms = DateTime.now().difference(startupT0).inMilliseconds;
            debugPrint('[Startup] +${ms}ms — $label');
          }
        }

        WidgetsFlutterBinding.ensureInitialized();
        logStartup('WidgetsFlutterBinding.ensureInitialized');

        if (Platform.isMacOS) {
          try {
            final Map<dynamic, dynamic>? debugResult =
                await const MethodChannel(
                  'com.breakmate.desktop/bridge',
                ).invokeMethod<Map<dynamic, dynamic>>('debugCalendarState');
            debugPrint('Startup debugCalendarState result: $debugResult');
          } catch (e) {
            debugPrint('Startup debugCalendarState failed: $e');
          }
        }

        bool isActualMain = true;
        if (Platform.isMacOS) {
          try {
            final res = await const MethodChannel(
              'com.breakmate.desktop/bridge',
            ).invokeMethod<bool>('checkIsMainEngine');
            isActualMain = res ?? true;
          } catch (_) {
            isActualMain = false;
          }
        }

        debugPrint('[Main] Is actual main engine: $isActualMain');

        if (!isActualMain) {
          debugPrint(
            '[Main] Secondary engine detected in main(). Redirecting...',
          );
          return;
        }

        FrameTimingLogger.instance.start();
        MemoryCheckpoints.instance.logCheckpoint('startup');
        _setupGlobalErrors();

        if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
          await Window.initialize();
        }

        ServerSocket? singleInstanceServer;

        if (isMainIsolate) {
          int port = 10425;
          bool bound = false;

          try {
            singleInstanceServer = await ServerSocket.bind(
              InternetAddress.loopbackIPv4,
              port,
            );
            debugPrint('Startup: Port $port bound (Main Instance)');
            bound = true;
          } catch (e) {
            debugPrint(
              'Startup: Primary port $port in use. Attempting process replacement...',
            );

            try {
              final socket = await Socket.connect(
                InternetAddress.loopbackIPv4,
                port,
                timeout: const Duration(milliseconds: 500),
              );
              socket.write('shutdown\n');
              await socket.flush();
              await socket.close();
              debugPrint(
                'Startup: Sent shutdown command to existing instance.',
              );

              int elapsed = 0;
              const int checkIntervalMs = 200;
              const int maxWaitMs = 3000;

              await Future.delayed(const Duration(milliseconds: 500));
              elapsed += 500;

              while (elapsed < maxWaitMs) {
                try {
                  singleInstanceServer = await ServerSocket.bind(
                    InternetAddress.loopbackIPv4,
                    port,
                  );
                  debugPrint(
                    'Startup: Port $port successfully bound after old instance shutdown at ${elapsed}ms.',
                  );
                  bound = true;
                  break;
                } catch (_) {
                  await Future.delayed(
                    const Duration(milliseconds: checkIntervalMs),
                  );
                  elapsed += checkIntervalMs;
                }
              }
            } catch (connectErr) {
              debugPrint(
                'Startup: Failed to connect to existing instance: $connectErr. Process may be dead but port remains locked.',
              );
            }

            if (!bound) {
              debugPrint(
                'Startup: Graceful shutdown failed. Force terminating stale process on port $port...',
              );
              try {
                final result = await Process.run('sh', [
                  '-c',
                  'PID=\$(lsof -t -s TCP:LISTEN -i :$port); [ -n "\$PID" ] && kill -9 \$PID',
                ]);
                debugPrint(
                  'Startup: Force terminate result: exitCode=${result.exitCode}',
                );

                await Future.delayed(const Duration(milliseconds: 500));

                singleInstanceServer = await ServerSocket.bind(
                  InternetAddress.loopbackIPv4,
                  port,
                );
                debugPrint(
                  'Startup: Port $port successfully bound after force termination.',
                );
                bound = true;
              } catch (killErr) {
                debugPrint(
                  'Startup: Failed to force terminate process: $killErr',
                );
              }
            }
          }

          if (!bound && !kDebugMode) {
            debugPrint(
              'Startup: Could not bind any single-instance port. Exiting.',
            );
            exit(1);
          }
        }

        _globalSingleInstanceServer = singleInstanceServer;

        if (!Platform.isWindows) {
          ProcessSignal.sigterm.watch().listen((_) async {
            debugPrint('[Signal] SIGTERM received — shutting down.');
            await _gracefulShutdown(_globalSingleInstanceServer);
          });
          ProcessSignal.sigint.watch().listen((_) async {
            debugPrint('[Signal] SIGINT received — shutting down.');
            await _gracefulShutdown(_globalSingleInstanceServer);
          });
        }

        await SimplePrefs.instance.init();
        logStartup('SimplePrefs.init');

        await initDependencies();
        await ServiceBootstrapper.bootstrap();
        IpcCoordinator.coordinate();
        logStartup('bootstrapping complete');

        await windowManager.ensureInitialized();
        logStartup('windowManager.ensureInitialized');

        WindowOptions windowOptions = WindowOptions(
          size: const Size(1100, 750),
          minimumSize: const Size(1100, 750),
          maximumSize: const Size(1100, 750),
          center: true,
          backgroundColor: Platform.isWindows
              ? AppTheme.sidebarBackground
              : Colors.transparent,
          skipTaskbar: false,
          titleBarStyle: Platform.isWindows
              ? TitleBarStyle.normal
              : TitleBarStyle.hidden,
        );

        await windowManager.waitUntilReadyToShow(windowOptions, () async {
          await windowManager.setPreventClose(true);
          await windowManager.setResizable(false);
          await windowManager.show();
          await windowManager.focus();
        });

        MethodChannel('com.breakmate.desktop/bridge').setMethodCallHandler((
          call,
        ) async {
          if (call.method == 'handleReopen') {
            await sl<OverlayWindowService>().showDashboard(forceShow: true);
          } else if (call.method == 'skipBreak') {
            sl<BreakController>().skipCurrentBreak();
          } else if (call.method == 'completeBreak') {
            sl<BreakController>().completeCurrentBreak();
          } else if (call.method == 'hideOverlay') {
            await sl<OverlayWindowService>().hideOverlay();
          } else if (call.method == 'quitApp') {
            sl<MenuBarController>().handleAction('quit');
          } else if (call.method == 'systemSleep') {
            sl<TimerEngine>().handleSystemSleep();
          } else if (call.method == 'systemWake') {
            sl<TimerEngine>().handleSystemWake();
          }
        });

        if (singleInstanceServer != null) {
          singleInstanceServer.listen((client) {
            utf8.decoder.bind(client).join().then((message) async {
              final cmd = message.trim();
              if (cmd == 'shutdown') {
                debugPrint('SingleInstanceServer: Received shutdown command.');
                await _gracefulShutdown(singleInstanceServer);
              } else if (cmd == 'showDashboard') {
                await sl<OverlayWindowService>().showDashboard(forceShow: true);
              }
              client.destroy();
            });
          });
        }

        try {
          PackageInfo packageInfo = await PackageInfo.fromPlatform();
          if (packageInfo.appName.isNotEmpty) {
            launchAtStartup.setup(
              appName: packageInfo.appName,
              appPath: Platform.resolvedExecutable,
            );
          }
        } catch (e) {
          debugPrint('Launch at startup setup failed: $e');
        }

        if (kReleaseMode &&
            config.sentryDsn.isNotEmpty &&
            config.sentryDsn != 'DEV_DSN_HERE') {
          await SentryFlutter.init(
            (options) {
              options.dsn = config.sentryDsn;
              options.enableAppHangTracking = false;
            },
            appRunner: () => runApp(SentryWidget(child: const BreakMateApp())),
          );
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            logStartup('first dashboard frame rendered');
          });
          runApp(const BreakMateApp());
        }
      } catch (e, stack) {
        debugPrint('FATAL STARTUP ERROR: $e');
        debugPrint(stack.toString());
        rethrow;
      }
    },
    (error, stack) {
      debugPrint('ZONED ERROR: $error');
      debugPrint(stack.toString());
      gracefulShutdown();
    },
  );
}

void _setupMinimalIpc() {
  final eventBus = EventBus.instance;
  IpcBridge.instance.setTypedEventHandler((event) {
    if (event is TimerStateChangedIpcEvent) {
      final targetEndTime = event.targetEndTime != null
          ? DateTime.fromMillisecondsSinceEpoch(event.targetEndTime!)
          : null;

      TimerStateEvent? timerState;
      switch (event.stateName) {
        case 'running':
          timerState = TimerStateEvent.running;
          break;
        case 'breakActive':
          timerState = TimerStateEvent.breakActive;
          break;
        case 'paused':
          timerState = TimerStateEvent.paused;
          break;
        case 'idle':
          timerState = TimerStateEvent.idle;
          break;
      }

      if (timerState != null) {
        eventBus.emit(
          TimerStateChangedEvent(
            state: timerState,
            countdownSeconds: event.countdownSeconds,
            workElapsedSeconds: event.workElapsedSeconds,
            targetEndTime: targetEndTime,
            totalWorkTodaySeconds: event.totalWorkTodaySeconds,
          ),
        );
      }
    } else if (event is MeetingDetectedIpcEvent) {
      eventBus.emit(
        MeetingDetectedEvent(
          isActive: event.isActive,
          bundleId: event.bundleId,
        ),
      );
    } else if (event is CompanionInteractionIpcEvent) {
      eventBus.emit(
        CompanionInteractionEvent(
          interactionType: event.interactionType,
          metadata: event.metadata,
        ),
      );
    }
  });
}

@pragma('vm:entry-point')
Future<void> overlayMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SimplePrefs.instance.init();
  _setupGlobalErrors();
  _setupMinimalIpc();
  if (Platform.isMacOS || Platform.isWindows) {
    await Window.initialize();
    try {
      await Window.setEffect(
        effect: WindowEffect.transparent,
        color: Colors.transparent,
      );
    } catch (e) {
      debugPrint('Window.setEffect failed: $e');
    }
  }

  if (!sl.isRegistered<StatsService>()) {
    sl.registerSingleton<StatsService>(FakeStatsService());
  }
  if (!sl.isRegistered<BreakController>()) {
    sl.registerSingleton<BreakController>(FakeBreakController());
  }

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      color: Colors.transparent,
      home: StandaloneBreakOverlay(),
    ),
  );
}

@pragma('vm:entry-point')
Future<void> companionMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SimplePrefs.instance.init();
  _setupGlobalErrors();
  _setupMinimalIpc();

  if (Platform.isMacOS || Platform.isWindows) {
    await Window.initialize();
    try {
      await Window.setEffect(
        effect: WindowEffect.transparent,
        color: Colors.transparent,
      );
    } catch (e) {
      debugPrint('Window.setEffect failed: $e');
    }
  }

  try {
    final defaultTheme = PetTheme.getTheme('grey_cat');
    await PetAssetLoader.loadAnimations(
      CompanionGame.getProfileFromTheme(defaultTheme),
    );
  } catch (e, st) {
    ErrorHandler().handleError(e, st);
  }

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CompanionOverlayWindow(),
    ),
  );
}

@pragma('vm:entry-point')
Future<void> pipMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SimplePrefs.instance.init();
  _setupGlobalErrors();
  _setupMinimalIpc();

  if (Platform.isMacOS || Platform.isWindows) {
    await Window.initialize();
    try {
      await Window.setEffect(
        effect: WindowEffect.transparent,
        color: Colors.transparent,
      );
    } catch (e) {
      debugPrint('Window.setEffect failed: $e');
    }
  }

  try {
    final defaultTheme = PetTheme.getTheme('grey_cat');
    await PetAssetLoader.loadAnimations(
      CompanionGame.getProfileFromTheme(defaultTheme),
    );
  } catch (e, st) {
    ErrorHandler().handleError(e, st);
  }

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PiPOverlayWindow(),
    ),
  );
}

class FakeStatsService extends ChangeNotifier implements StatsService {
  StatsModel _stats = const StatsModel();

  @override
  StatsModel get stats => _stats;

  void updateBreaksCompleted(int count) {
    _stats = _stats.copyWith(breaksCompleted: count);
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeBreakController extends ChangeNotifier implements BreakController {
  @override
  Future<void> completeCurrentBreak() async {
    const MethodChannel(
      'com.breakmate.desktop/bridge',
    ).invokeMethod('completeBreak');
  }

  @override
  Future<void> skipCurrentBreak() async {
    const MethodChannel(
      'com.breakmate.desktop/bridge',
    ).invokeMethod('skipBreak');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
