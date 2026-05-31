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
import 'package:breakmate/app/app.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/services/overlay_window_service.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/features/break_system/presentation/standalone_break_overlay.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:breakmate/features/companion/assets/pet_asset_loader.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/flame/companion_game.dart';
import 'package:breakmate/features/companion/overlay/companion_overlay_window.dart';

import 'package:window_manager/window_manager.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/core/services/error_toast_service.dart';

import 'package:breakmate/core/ipc/ipc_bridge.dart';
import 'package:breakmate/core/ipc/ipc_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/utils/frame_timing_logger.dart';
import 'package:breakmate/core/utils/memory_checkpoints.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void _setupGlobalErrors() {
  // 1. Log Flutter errors to console
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('=== FLUTTER ERROR ===');
    debugPrint(details.exceptionAsString());
    debugPrint(details.stack?.toString());

    // Ignore harmless framework-level hardware keyboard assertions on desktop
    final exceptionStr = details.exceptionAsString();
    final isHardwareKeyboardAssert =
        exceptionStr.contains('HardwareKeyboard') ||
        exceptionStr.contains('_pressedKeys.containsKey');

    if (!details.silent && !isHardwareKeyboardAssert) {
      ErrorToastService.showError('Oops! An internal error occurred.');
    }
    FlutterError.presentError(details); // Calls ErrorWidget.builder
  };

  // 2. Async Dart errors
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('=== ASYNC DART ERROR ===');
    debugPrint(error.toString());
    debugPrint(stack.toString());
    ErrorToastService.showError('Oops! An action failed. Please try again.');
    return true; // Prevent default crash behavior
  };

  // 3. User friendly UI for render errors
  ErrorWidget.builder = (FlutterErrorDetails details) {
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

void main() async {
  final isolateName = Isolate.current.debugName ?? '';
  // On macOS desktop, secondary engines often have names like "OverlayEngine-..."
  final isMainIsolate = !isolateName.toLowerCase().contains('overlay') &&
      !isolateName.toLowerCase().contains('companion');

  // If we are in an overlay or companion isolate, jump to the correct entry point.
  // This is a safety layer for when the Flutter engine runs main() by default.
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
          debugPrint('[Main] Secondary engine detected in main(). Redirecting...');
          // On macOS, secondary engines should have their own entry points.
          // If we reach here, it means the isolate name didn't match but it's not the main engine.
          // We must NOT call initDependencies() here.
          return;
        }

        FrameTimingLogger.instance.start();
        MemoryCheckpoints.instance.logCheckpoint('startup');
        _setupGlobalErrors();

        // Initialize flutter_acrylic for glassmorphic effect
        if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
          await Window.initialize();
        }

        ServerSocket? singleInstanceServer;

        // ONLY the main isolate should perform the port check and potentially call exit().
        if (isMainIsolate) {
          int startPort = 10425;
          int endPort = kDebugMode ? 10430 : 10425;
          bool bound = false;

          for (int port = startPort; port <= endPort; port++) {
            try {
              singleInstanceServer = await ServerSocket.bind(
                InternetAddress.loopbackIPv4,
                port,
              );
              debugPrint('Startup: Port $port bound (Main Instance)');
              bound = true;
              break;
            } catch (e) {
              if (port == startPort) {
                debugPrint('Startup: Primary port $port in use');
                
                // Signal existing instance
                try {
                  final socket = await Socket.connect(
                    InternetAddress.loopbackIPv4,
                    port,
                    timeout: const Duration(milliseconds: 500),
                  );
                  socket.write('showDashboard\n');
                  await socket.flush();
                  await socket.close();
                  debugPrint('Startup: Signaled existing instance.');
                  
                  if (!kDebugMode) {
                    debugPrint('Startup: Exiting (Single Instance enforced)');
                    exit(0);
                  } else {
                    debugPrint('Startup: Continuing in Debug Mode on fallback port...');
                  }
                } catch (signalError) {
                  debugPrint('Startup: Existing instance not responding (Port stuck).');
                }
              }
            }
          }
          
          if (!bound && !kDebugMode) {
             debugPrint('Startup: Could not bind any single-instance port. Exiting.');
             exit(1);
          }
        }

        // Initialize all dependencies
        await initDependencies();
        logStartup('initDependencies complete');

        // Initialize Window Manager
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
          await windowManager.hide();
        });

        MethodChannel('com.breakmate.desktop/bridge').setMethodCallHandler((
          call,
        ) async {
          if (call.method == 'handleReopen') {
            await sl<OverlayWindowService>().showDashboard(forceShow: true);
          } else if (call.method == 'skipBreak') {
            sl<BreakController>().skipCurrentBreak();
          } else if (call.method == 'systemSleep') {
            sl<TimerEngine>().handleSystemSleep();
          } else if (call.method == 'systemWake') {
            sl<TimerEngine>().handleSystemWake();
          }
        });

        if (singleInstanceServer != null) {
          singleInstanceServer.listen((client) {
            utf8.decoder.bind(client).join().then((message) async {
              if (message.trim() == 'showDashboard') {
                await sl<OverlayWindowService>().showDashboard(forceShow: true);
              }
              client.destroy();
            });
          });
        }

        // Setup Launch at Startup
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

        if (kReleaseMode) {
          await SentryFlutter.init((options) {
            options.dsn =
                'https://3287665b86c8b294c6dbb5fead66c05b@o4511460809637888.ingest.de.sentry.io/4511460813963344';
          }, appRunner: () => runApp(SentryWidget(child: const BreakMateApp())));
        } else {
          // Log first dashboard frame time in debug mode
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
    },
  );
}

void _setupMinimalIpc() {
  final eventBus = EventBus.instance;
  IpcBridge.instance.setEventHandler((event, data) {
    switch (event) {
      case IpcEventNames.timerStateChanged:
        final stateStr = data['state'] as String?;
        final countdown = (data['countdownSeconds'] as num?)?.toInt() ?? 0;
        final elapsed = (data['workElapsedSeconds'] as num?)?.toInt() ?? 0;
        final targetEndMs = data['targetEndTime'] as int?;
        final targetEndTime = targetEndMs != null
            ? DateTime.fromMillisecondsSinceEpoch(targetEndMs)
            : null;
        final totalWorkTodaySecs = (data['totalWorkTodaySeconds'] as num?)
            ?.toInt();
        TimerStateEvent? timerState;
        switch (stateStr) {
          case 'running':
            timerState = TimerStateEvent.running;
          case 'breakActive':
            timerState = TimerStateEvent.breakActive;
          case 'paused':
            timerState = TimerStateEvent.paused;
          case 'idle':
            timerState = TimerStateEvent.idle;
        }
        if (timerState != null) {
          eventBus.emit(
            TimerStateChangedEvent(
              state: timerState,
              countdownSeconds: countdown,
              workElapsedSeconds: elapsed,
              targetEndTime: targetEndTime,
              totalWorkTodaySeconds: totalWorkTodaySecs,
            ),
          );
        }
      case 'detection.meeting':
        eventBus.emit(
          MeetingDetectedEvent(
            isActive: data['isActive'] as bool? ?? false,
            bundleId: data['bundleId'] as String? ?? '',
          ),
        );
      case IpcEventNames.companionInteraction:
        eventBus.emit(
          CompanionInteractionEvent(
            interactionType: data['interactionType'] as String? ?? 'click',
            metadata: data['metadata'] != null
                ? Map<String, dynamic>.from(data['metadata'] as Map)
                : null,
          ),
        );
    }
  });
}

@pragma('vm:entry-point')
Future<void> overlayMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  _setupGlobalErrors();
  _setupMinimalIpc();

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StandaloneBreakOverlay(),
    ),
  );
}

@pragma('vm:entry-point')
Future<void> companionMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  _setupGlobalErrors();
  _setupMinimalIpc();

  // On macOS, initialize flutter_acrylic for the companion panel.
  if (Platform.isMacOS) {
    await Window.initialize();
  }

  // Pre-load the default cat theme to warm up the Flame engine and image codec
  // This significantly reduces the "blank screen" time when the companion is first shown.
  try {
    final defaultTheme = PetTheme.getTheme('grey_cat');
    await PetAssetLoader.loadAnimations(
      CompanionGame.getProfileFromTheme(defaultTheme),
    );
  } catch (_) {}

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CompanionOverlayWindow(),
    ),
  );
}
