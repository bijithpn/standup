import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:standup/app/app.dart';
import 'package:standup/app/dependency_injection.dart';
import 'package:standup/core/services/app_navigation_service.dart';
import 'package:standup/core/services/overlay_window_service.dart';
import 'package:standup/features/break_system/presentation/standalone_break_overlay.dart';
import 'package:standup/features/flash_overlay/flash_overlay_service.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';

void main() async {
  runZonedGuarded(() async {
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
        singleInstanceServer =
            await ServerSocket.bind(InternetAddress.loopbackIPv4, 10425);
        debugPrint('Startup: Port 10425 bound');
      } catch (e) {
        debugPrint('Startup: Port 10425 already in use - another instance is running');
        try {
          final socket = await Socket.connect(
            InternetAddress.loopbackIPv4,
            10425,
            timeout: const Duration(milliseconds: 500),
          );
          socket.write('showDashboard\n');
          await socket.flush();
          await socket.close();
        } catch (signalError) {
          debugPrint('Startup: Could not signal existing instance');
        }
        exit(0);
      }

      // Initialize all dependencies
      await initDependencies();

      // Initialize Window Manager
      await windowManager.ensureInitialized();

      WindowOptions windowOptions = const WindowOptions(
        size: Size(1100, 750),
        minimumSize: Size(400, 600),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden,
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.setPreventClose(true);
        await windowManager.hide();
      });

      singleInstanceServer.listen((client) {
        utf8.decoder.bind(client).join().then((message) async {
          if (message.trim() == 'showDashboard') {
            sl<AppNavigationService>().openSection('Companion');
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

      // Start flash overlay timer
      final flashOverlayService = sl<FlashOverlayService>();
      flashOverlayService.startTimer();

      runApp(
        const BreakMateApp(),
      );
    } catch (e, stack) {
      debugPrint('FATAL STARTUP ERROR: $e');
      debugPrint(stack.toString());
      rethrow;
    }
  }, (error, stack) {
    debugPrint('ZONED ERROR: $error');
    debugPrint(stack.toString());
  });
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
