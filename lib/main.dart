import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:standup/app/app.dart';
import 'package:standup/app/dependency_injection.dart';
import 'package:standup/core/services/overlay_window_service.dart';
import 'package:standup/features/break_system/presentation/standalone_break_overlay.dart';
import 'package:standup/features/break_system/application/break_controller.dart';
import 'package:standup/features/companion/assets/pet_asset_loader.dart';
import 'package:standup/features/companion/domain/cat_theme.dart';
import 'package:standup/features/companion/flame/companion_game.dart';
import 'package:standup/features/companion/overlay/companion_overlay_window.dart';

import 'package:window_manager/window_manager.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:standup/shared/theme/app_theme.dart';

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

        // Initialize flutter_acrylic for glassmorphic effect
        if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
          await Window.initialize();
        }

        ServerSocket? singleInstanceServer;

        // ONLY the main isolate should perform the port check and potentially call exit().
        if (isMainIsolate) {
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
          minimumSize: const Size(400, 600),
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
          await windowManager.hide();
        });

        MethodChannel('com.breakmate.macos/bridge').setMethodCallHandler((
          call,
        ) async {
          if (call.method == 'handleReopen') {
            await sl<OverlayWindowService>().showDashboard();
          } else if (call.method == 'skipBreak') {
            sl<BreakController>().skipCurrentBreak();
          }
        });

        if (singleInstanceServer != null) {
          singleInstanceServer.listen((client) {
            utf8.decoder.bind(client).join().then((message) async {
              if (message.trim() == 'showDashboard') {
                await sl<OverlayWindowService>().showDashboard();
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

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();

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

  // On macOS, initialize flutter_acrylic for the companion panel.
  if (Platform.isMacOS) {
    await Window.initialize();
  }

  // Pre-load the default cat theme to warm up the Flame engine and image codec
  // This significantly reduces the "blank screen" time when the companion is first shown.
  try {
    final defaultTheme = CatTheme.getTheme('grey_cat');
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
