import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:standup/app/app.dart';
import 'package:standup/app/dependency_injection.dart';
import 'package:standup/core/services/app_navigation_service.dart';
import 'package:standup/core/services/overlay_window_service.dart';
import 'package:standup/features/break_system/presentation/standalone_break_overlay.dart';
import 'package:standup/features/companion/overlay/companion_overlay_window.dart';

import 'package:window_manager/window_manager.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:standup/shared/theme/app_theme.dart';

void main() async {
  // If we are in an overlay engine, we should NOT run the main application logic
  // This is a safety check because sometimes Flutter engines fall back to main()
  if (Platform.environment.containsKey('FLUTTER_ENTRYPOINT') &&
      Platform.environment['FLUTTER_ENTRYPOINT'] == 'overlayMain') {
    overlayMain();
    return;
  }

  runZonedGuarded(
    () async {
      try {
        WidgetsFlutterBinding.ensureInitialized();
        debugPrint('Startup: Widgets initialized');

        // Initialize flutter_acrylic for glassmorphic effect
        if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
          await Window.initialize();
          debugPrint('Startup: Acrylic window initialized');
        }

        ServerSocket? singleInstanceServer;

        // Single instance check via Socket.
        try {
          singleInstanceServer = await ServerSocket.bind(
            InternetAddress.loopbackIPv4,
            10425,
          );
          debugPrint('Startup: Port 10425 bound (Main Instance)');
        } catch (e) {
          debugPrint('Startup: Port 10425 already in use');

          // This might be the main instance restarting or an overlay engine misfiring.
          // We attempt to signal the existing instance.
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
            // If we can't connect, maybe the port is stuck.
            // In a production app, we might want to handle this differently.
            debugPrint(
              'Startup: Could not signal existing instance (Port might be stuck)',
            );
            exit(1);
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
          backgroundColor: Platform.isWindows ? AppTheme.sidebarBackground : Colors.transparent,
          skipTaskbar: false,
          titleBarStyle: Platform.isWindows ? TitleBarStyle.normal : TitleBarStyle.hidden,
        );

        await windowManager.waitUntilReadyToShow(windowOptions, () async {
          await windowManager.setPreventClose(true);
          await windowManager.hide();
        });

        MethodChannel('com.breakmate.macos/bridge').setMethodCallHandler((
          call,
        ) async {
          if (call.method == 'handleReopen') {
            sl<AppNavigationService>().openSection('General');
            await sl<OverlayWindowService>().showDashboard();
          }
        });

        singleInstanceServer.listen((client) {
          utf8.decoder.bind(client).join().then((message) async {
            if (message.trim() == 'showDashboard') {
              sl<AppNavigationService>().openSection('General');
              await sl<OverlayWindowService>().showDashboard();
            }
            client.destroy();
          });
        });

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
  // On Windows, the C++ CompanionWindowManager already configured the Win32
  // window — calling Window.initialize() again would conflict.
  if (Platform.isMacOS) {
    await Window.initialize();
  }
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CompanionOverlayWindow(),
    ),
  );
}

