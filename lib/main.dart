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
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/events/app_events.dart';

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
                  fontFamily: 'Satoshi',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'An unexpected error occurred. We have logged the details.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontFamily: 'Satoshi',
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
  final isMainIsolate =
      isolateName == 'main' || isolateName == 'root' || isolateName.isEmpty;

  // If we are in an overlay or companion isolate, jump to the correct entry point.
  // This is a safety layer for when the Flutter engine runs main() by default.
  if (isolateName.contains('overlayMain')) {
    overlayMain();
    return;
  } else if (isolateName.contains('companionMain')) {
    companionMain();
    return;
  }

  runZonedGuarded(
    () async {
      try {
        WidgetsFlutterBinding.ensureInitialized();
        _setupGlobalErrors();

        // Initialize flutter_acrylic for glassmorphic effect
        if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
          await Window.initialize();
        }

        ServerSocket? singleInstanceServer;

        bool isActualMain = true;
        if (Platform.isMacOS) {
          try {
            final res = await const MethodChannel(
              'com.breakmate.macos/bridge',
            ).invokeMethod<bool>('checkIsMainEngine');
            isActualMain = res ?? true;
          } catch (_) {
            isActualMain = false;
          }
        }

        // ONLY the main isolate should perform the port check and potentially call exit().
        if (isMainIsolate && isActualMain) {
          try {
            singleInstanceServer = await ServerSocket.bind(
              InternetAddress.loopbackIPv4,
              10425,
            );
            debugPrint('Startup: Port 10425 bound (Main Instance)');
          } catch (e) {
            debugPrint('Startup: Port 10425 already in use');

            // Signal existing instance and EXIT the process
            try {
              final socket = await Socket.connect(
                InternetAddress.loopbackIPv4,
                10425,
                timeout: const Duration(milliseconds: 500),
              );
              socket.write('showDashboard\n');
              await socket.flush();
              await socket.close();
              debugPrint('Startup: Signaled existing instance. Exiting.');
              exit(0);
            } catch (signalError) {
              debugPrint(
                'Startup: Could not signal existing instance (Port stuck)',
              );
              exit(1);
            }
          }
        }

        // Initialize all dependencies
        await initDependencies();

        // Initialize Window Manager
        await windowManager.ensureInitialized();

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

        MethodChannel('com.breakmate.macos/bridge').setMethodCallHandler((
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

        runApp(const BreakMateApp());
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
      case 'timer.stateChanged':
        final stateStr = data['state'] as String?;
        final countdown = (data['countdownSeconds'] as num?)?.toInt() ?? 0;
        final elapsed = (data['workElapsedSeconds'] as num?)?.toInt() ?? 0;
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
    }
  });
}

@pragma('vm:entry-point')
void overlayMain() {
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
