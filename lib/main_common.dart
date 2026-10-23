import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:breakmate/core/services/daily_reset_service.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene_catalog.dart';
import 'package:breakmate/features/companion/services/custom_environment_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'app/startup_splash.dart';
import 'app/bootstrapping/ipc_coordinator.dart';
import 'app/bootstrapping/service_bootstrapper.dart';
import 'package:path_provider/path_provider.dart';
import 'core/core.dart';
import 'core/ipc/single_instance_token.dart';
import 'core/utils/file_permissions.dart';
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
      ErrorHandler().handleError(details.exception, details.stack);
      ErrorToastService.showError('Oops! An internal error occurred.');

      // Unhandled layout exceptions do not immediately terminate the process;
      // however, UI instability may require recovery triggers.
    }
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('=== ASYNC DART ERROR ===');
    debugPrint(error.toString());
    debugPrint(stack.toString());

    ErrorHandler().handleError(error, stack, type: AppErrorType.general);
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

    // Override the default Flutter red screen of death with a styled recovery widget.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: const Color(0xFF1E1E2E),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_rounded,
                    color: Colors.redAccent,
                    size: 56,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Application Error',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Something unexpected happened.\nWe are sorry for the inconvenience.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.4,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white10,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    _gracefulShutdown(
                      _globalSingleInstanceServer,
                    ).then((_) => exit(1));
                  },
                  icon: const Icon(Icons.power_settings_new, size: 18),
                  label: const Text('Close App'),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.2),
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        '${details.exceptionAsString()}\n\n${details.stack?.toString() ?? "No stack trace available."}',
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
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

Future<void> _gracefulShutdown(
  ServerSocket? serverSocket, [
  String? reason,
]) async {
  debugPrint(
    '[Shutdown] Starting graceful shutdown (reason: $reason) from:\n${StackTrace.current}',
  );

  try {
    if (sl.isRegistered<SettingsRepository>()) {
      final settingsRepo = sl<SettingsRepository>();
      await settingsRepo.save(settingsRepo.currentSettings);
      debugPrint('[Shutdown] Settings saved & flushed.');
    }
  } catch (e, st) {
    ErrorHandler().handleError(e, st, type: AppErrorType.storage);
  }

  try {
    if (sl.isRegistered<OverlayWindowService>()) {
      await sl<OverlayWindowService>().reset();
      debugPrint('[Shutdown] OverlayWindowService reset complete.');
    }
  } catch (e, st) {
    ErrorHandler().handleError(e, st, type: AppErrorType.ui);
  }

  try {
    await NativeBridge.hideCompanion();
    debugPrint('[Shutdown] Companion hidden.');
  } catch (e, st) {
    ErrorHandler().handleError(e, st, type: AppErrorType.native);
  }

  try {
    await NativeBridge.hidePipWindow();
    debugPrint('[Shutdown] PiP Window hidden.');
  } catch (e, st) {
    ErrorHandler().handleError(e, st, type: AppErrorType.native);
  }

  try {
    await NativeBridge.hideOverlay();
    debugPrint('[Shutdown] Overlay hidden.');
  } catch (e, st) {
    ErrorHandler().handleError(e, st, type: AppErrorType.native);
  }

  try {
    if (sl.isRegistered<TimerOrchestrator>()) {
      sl<TimerOrchestrator>().shutdown();
      debugPrint('[Shutdown] TimerOrchestrator shutdown complete.');
    }
  } catch (e, st) {
    ErrorHandler().handleError(e, st, type: AppErrorType.timer);
  }

  try {
    if (sl.isRegistered<TimerEngine>()) {
      sl<TimerEngine>().dispose();
      debugPrint('[Shutdown] TimerEngine disposed.');
    }
  } catch (e, st) {
    ErrorHandler().handleError(e, st, type: AppErrorType.timer);
  }

  try {
    if (sl.isRegistered<SmartDetectionService>()) {
      sl<SmartDetectionService>().dispose();
      debugPrint('[Shutdown] SmartDetectionService disposed.');
    }
  } catch (e, st) {
    ErrorHandler().handleError(e, st, type: AppErrorType.activityMonitor);
  }

  try {
    if (serverSocket != null) {
      await serverSocket.close();
      debugPrint('[Shutdown] Single-instance server socket closed.');
    }
  } catch (e, st) {
    ErrorHandler().handleError(e, st);
  }

  try {
    if (sl.isRegistered<TrayManagerService>()) {
      sl<TrayManagerService>().dispose();
      debugPrint('[Shutdown] TrayManagerService disposed.');
    }
    await trayManager.destroy();
    debugPrint('[Shutdown] Tray icon destroyed.');
  } catch (e, st) {
    ErrorHandler().handleError(e, st, type: AppErrorType.ui);
  }

  try {
    if (sl.isRegistered<StorageService>()) {
      sl<StorageService>().close();
      debugPrint('[Shutdown] StorageService closed cleanly.');
    }
  } catch (e, st) {
    ErrorHandler().handleError(e, st, type: AppErrorType.storage);
  }

  debugPrint('[Shutdown] Graceful shutdown complete. Exiting.');
  exit(0);
}

Future<List<int>> _getPidsListeningOnPort(int port) async {
  final pids = <int>[];
  if (Platform.isWindows) {
    try {
      final result = await Process.run('netstat', ['-ano', '-p', 'tcp']);
      if (result.exitCode == 0) {
        final lines = LineSplitter.split(result.stdout.toString());
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.contains(':$port') && trimmed.contains('LISTENING')) {
            final parts = trimmed.split(RegExp(r'\s+'));
            if (parts.length >= 5) {
              final pidVal = int.tryParse(parts.last);
              if (pidVal != null && pidVal != pid) {
                pids.add(pidVal);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to run netstat: $e');
    }
  } else {
    try {
      final result = await Process.run('lsof', [
        '-t',
        '-s',
        'TCP:LISTEN',
        '-i',
        ':$port',
      ]);
      if (result.exitCode == 0) {
        final lines = LineSplitter.split(result.stdout.toString());
        for (final line in lines) {
          final pidVal = int.tryParse(line.trim());
          if (pidVal != null && pidVal != pid) {
            pids.add(pidVal);
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to run lsof: $e');
    }
  }
  return pids;
}

Future<void> gracefulShutdown([String? reason]) async {
  await _gracefulShutdown(_globalSingleInstanceServer, reason);
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
        final startupMarks = <MapEntry<String, int>>[];
        void logStartup(String label) {
          if (!kReleaseMode) {
            final ms = DateTime.now().difference(startupT0).inMilliseconds;
            startupMarks.add(MapEntry(label, ms));
            debugPrint('[Startup] +${ms}ms — $label');
            if (label == 'first dashboard frame rendered') {
              // Slowest steps = largest gap to the previous checkpoint.
              final gaps = <MapEntry<String, int>>[
                for (var i = 1; i < startupMarks.length; i++)
                  MapEntry(
                    startupMarks[i].key,
                    startupMarks[i].value - startupMarks[i - 1].value,
                  ),
              ]..sort((a, b) => b.value.compareTo(a.value));
              debugPrint('[Startup] Slowest steps:');
              for (final g in gaps.take(5)) {
                debugPrint('[Startup]   ${g.value}ms — ${g.key}');
              }
            }
          }
        }

        WidgetsFlutterBinding.ensureInitialized();
        logStartup('WidgetsFlutterBinding.ensureInitialized');

        if (kDebugMode && Platform.isMacOS) {
          // Diagnostic only; must never delay startup.
          unawaited(
            const MethodChannel('com.breakmate.desktop/bridge')
                .invokeMethod<Map<dynamic, dynamic>>('debugCalendarState')
                .then((r) => debugPrint('Startup debugCalendarState: $r'))
                .catchError((Object e) {
                  debugPrint('Startup debugCalendarState failed: $e');
                }),
          );
        }

        logStartup('debug calendar call dispatched');
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

        // Window plugins are independent of the services below, so start them
        // now and join once the dependencies are ready.
        final Future<void> windowInit =
            (Platform.isMacOS || Platform.isWindows || Platform.isLinux)
            ? Window.initialize()
            : Future<void>.value();
        windowInit.ignore();
        final Future<void> windowManagerInit = windowManager
            .ensureInitialized();
        windowManagerInit.ignore();

        ServerSocket? singleInstanceServer;

        if (isMainIsolate) {
          // One loopback port per flavor, so a dev build never talks to (or
          // force-kills) a running production app.
          final int port = config.isDev ? 10426 : 10425;
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
              final token = await SingleInstanceToken.read(
                await getApplicationSupportDirectory(),
              );
              socket.write('${token ?? ''} shutdown\n');
              await socket.flush();
              await socket.close();
              debugPrint(
                'Startup: Sent shutdown command to existing instance.',
              );

              int elapsed = 0;
              const int checkIntervalMs = 100;
              const int maxWaitMs = 3000;

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
                final pids = await _getPidsListeningOnPort(port);
                if (pids.isNotEmpty) {
                  debugPrint(
                    'Startup: Found stale processes holding port $port: $pids. Terminating...',
                  );
                  for (final targetPid in pids) {
                    try {
                      final success = Process.killPid(
                        targetPid,
                        ProcessSignal.sigkill,
                      );
                      debugPrint(
                        'Startup: Terminated stale PID $targetPid (success=$success)',
                      );
                    } catch (e) {
                      debugPrint(
                        'Startup: Failed to terminate PID $targetPid: $e',
                      );
                    }
                  }
                  await Future.delayed(const Duration(milliseconds: 500));
                }

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

          if (!bound) {
            if (kDebugMode) {
              try {
                singleInstanceServer = await ServerSocket.bind(
                  InternetAddress.loopbackIPv4,
                  0,
                );
                debugPrint(
                  'Startup: Bound ephemeral port ${singleInstanceServer.port} in debug mode',
                );
                bound = true;
              } catch (e) {
                debugPrint(
                  'Startup: Ephemeral port bind failed in debug mode: $e',
                );
              }
            } else {
              debugPrint(
                'Startup: Could not bind any single-instance port. Exiting.',
              );
              exit(1);
            }
          }
        }

        _globalSingleInstanceServer = singleInstanceServer;
        logStartup('single-instance port ready');

        // The permissions fix and the IPC token only share the support
        // directory, so run them side by side.
        final supportDir = await getApplicationSupportDirectory();
        String? ipcToken;
        await Future.wait([
          if (isMainIsolate) restrictToOwner(supportDir.path, directory: true),
          if (singleInstanceServer != null)
            SingleInstanceToken.create(
              supportDir,
            ).then<void>((t) => ipcToken = t).catchError((Object e) {
              debugPrint('Startup: Could not create IPC token: $e');
            }),
        ]);

        logStartup('ipc token ready');

        if (!Platform.isWindows) {
          ProcessSignal.sigterm.watch().listen((_) async {
            debugPrint('[Signal] SIGTERM received — shutting down.');
            await _gracefulShutdown(
              _globalSingleInstanceServer,
              'ProcessSignal.sigterm',
            );
          });
          ProcessSignal.sigint.watch().listen((_) async {
            debugPrint('[Signal] SIGINT received — shutting down.');
            await _gracefulShutdown(
              _globalSingleInstanceServer,
              'ProcessSignal.sigint',
            );
          });
        }

        await Future.wait([windowInit, windowManagerInit]);
        logStartup('window plugins ready');

        // Prefs only need the file system; read them while the window opens.
        final Future<void> prefsInit = SimplePrefs.instance.init();
        prefsInit.ignore();

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

        try {
          await windowManager
              .waitUntilReadyToShow(windowOptions, () async {
                await windowManager.setPreventClose(true);
                await windowManager.setResizable(false);
                await windowManager.show();
                await windowManager.focus();
                if (Platform.isMacOS) {
                  await NativeBridge.focusApp();
                }
              })
              .timeout(const Duration(seconds: 5));
        } on TimeoutException {
          // A stuck native call used to leave the app without a widget tree.
          debugPrint('[Startup] Window setup timed out; continuing to runApp.');
        }
        logStartup('window ready');

        // Paint something immediately; the real app replaces it once ready.
        runApp(const StartupSplash());
        logStartup('splash shown');

        try {
          await prefsInit;
          logStartup('SimplePrefs.init');

          await initDependencies();
          await ServiceBootstrapper.bootstrap();
          IpcCoordinator.coordinate();
          logStartup('bootstrapping complete');
        } catch (e, st) {
          ErrorHandler().handleError(e, st, type: AppErrorType.general);
          ErrorToastService.showError('Startup failed. The app will close.');
          await Future.delayed(const Duration(seconds: 3));
          await _gracefulShutdown(
            _globalSingleInstanceServer,
            'startup exception: $e',
          );
          return;
        }

        MethodChannel('com.breakmate.desktop/bridge').setMethodCallHandler((
          call,
        ) async {
          if (call.method == 'handleReopen') {
            await sl<OverlayWindowService>().showDashboard(forceShow: true);
          } else if (call.method == 'skipBreak') {
            sl<BreakController>().skipCurrentBreak();
          } else if (call.method == 'completeBreak') {
            final args = call.arguments;
            sl<BreakController>().completeCurrentBreak(
              lookedAway: args is Map && args['lookedAway'] == true,
            );
          } else if (call.method == 'hideOverlay') {
            await sl<OverlayWindowService>().hideOverlay();
          } else if (call.method == 'quitApp') {
            sl<MenuBarController>().handleAction('quit');
          } else if (call.method == 'systemSleep') {
            sl<TimerEngine>().handleSystemSleep();
          } else if (call.method == 'systemWake') {
            sl<TimerEngine>().handleSystemWake();
            // The overlay window keeps its own end time; send the extended one.
            sl<BreakController>().refreshSettings();
            sl<DailyResetService>().onSystemWake();
          } else if (call.method == 'onAvatarSaved') {
            final urlParams = call.arguments?['urlParams'] as String?;
            if (urlParams != null &&
                sl.isRegistered<CompanionOverlayController>()) {
              await sl<CompanionOverlayController>().saveAvatarUrlParams(
                urlParams,
              );
            }
          } else if (call.method == 'onPipBackgroundStyleChanged') {
            final style = call.arguments?['style'] as String?;
            if (style != null &&
                sl.isRegistered<CompanionOverlayController>()) {
              await sl<CompanionOverlayController>().changePipBackgroundStyle(
                style,
              );
            }
          }
        });

        if (singleInstanceServer != null) {
          singleInstanceServer.listen((client) {
            utf8.decoder.bind(client).join().then((message) async {
              final cmd = SingleInstanceToken.authorize(message, ipcToken);
              if (cmd == 'shutdown') {
                debugPrint('SingleInstanceServer: Received shutdown command.');
                await _gracefulShutdown(
                  singleInstanceServer,
                  'singleInstanceServer IPC: shutdown',
                );
              } else if (cmd == 'showDashboard') {
                await sl<OverlayWindowService>().showDashboard(forceShow: true);
              }
              client.destroy();
            });
          });
        }

        try {
          PackageInfo packageInfo = await PackageInfo.fromPlatform().timeout(
            const Duration(seconds: 3),
          );
          logStartup('package info ready');
          if (packageInfo.appName.isNotEmpty) {
            launchAtStartup.setup(
              appName: packageInfo.appName,
              appPath: Platform.resolvedExecutable,
            );
          }
        } catch (e) {
          debugPrint('Launch at startup setup failed: $e');
        }

        final crashReportingEnabled = SimplePrefs.instance.getBool(
          AppConstants.keyCrashReportingEnabled,
          defaultValue: true,
        );
        if (kReleaseMode &&
            crashReportingEnabled &&
            config.sentryDsn.isNotEmpty &&
            config.sentryDsn != 'DEV_DSN_HERE') {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            logStartup('first dashboard frame rendered');
            if (Platform.isMacOS) {
              try {
                await windowManager.show();
                await windowManager.focus();
                await NativeBridge.focusApp();
              } catch (e) {
                debugPrint('PostFrame window focus failed: $e');
              }
            }
          });
          await SentryFlutter.init(
            (options) {
              options.dsn = config.sentryDsn;
              options.enableAppHangTracking = false;
              SentryHygiene.configure(options);
              SentryHygiene.isEnabled = () => SimplePrefs.instance.getBool(
                AppConstants.keyCrashReportingEnabled,
                defaultValue: true,
              );
            },
            appRunner: () => runApp(SentryWidget(child: const BreakMateApp())),
          );
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            logStartup('first dashboard frame rendered');
            if (Platform.isMacOS) {
              try {
                await windowManager.show();
                await windowManager.focus();
                await NativeBridge.focusApp();
              } catch (e) {
                debugPrint('PostFrame window focus failed: $e');
              }
            }
          });
          logStartup('launching BreakMateApp');
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
      ErrorHandler().handleError(error, stack, type: AppErrorType.general);
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

  // The companion is the first thing these windows draw, so have its scenes
  // parsed before the first frame rather than a beat after it.
  unawaited(AvatarSceneCatalog.instance.load());

  try {
    CustomEnvironmentRepository().loadSync();
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

  // The companion is the first thing these windows draw, so have its scenes
  // parsed before the first frame rather than a beat after it.
  unawaited(AvatarSceneCatalog.instance.load());

  try {
    CustomEnvironmentRepository().loadSync();
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
  Future<void> completeCurrentBreak({bool lookedAway = false}) async {
    const MethodChannel(
      'com.breakmate.desktop/bridge',
    ).invokeMethod('completeBreak', {'lookedAway': lookedAway});
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
