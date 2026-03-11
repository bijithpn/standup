import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:standup/app/app.dart';
import 'package:standup/app/dependency_injection.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  runZonedGuarded(() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      debugPrint('Startup: Widgets initialized');
      
      // Single instance check via Socket
      try {
        await ServerSocket.bind(InternetAddress.loopbackIPv4, 10425);
        debugPrint('Startup: Port 10425 bound (single instance check passed)');
      } catch (e) {
        debugPrint('Startup: Port 10425 already in use - another instance is running ($e)');
        exit(0);
      }

      // Initialize all dependencies
      debugPrint('Startup: Initializing dependencies...');
      await initDependencies();
      debugPrint('Startup: Dependencies initialized');

      // Initialize Window Manager
      await windowManager.ensureInitialized();
      debugPrint('Startup: Window Manager initialized');

      WindowOptions windowOptions = const WindowOptions(
        size: Size(500, 700),
        center: true,
        backgroundColor: Colors.black,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden,
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.setPreventClose(true);
        // We start hidden as it's a tray app
        await windowManager.hide();
        debugPrint('Startup: Window ready and hidden');
      });

      // Setup Launch at Startup
      try {
        PackageInfo packageInfo = await PackageInfo.fromPlatform();
        if (packageInfo.appName.isNotEmpty) {
          launchAtStartup.setup(
            appName: packageInfo.appName,
            appPath: Platform.resolvedExecutable,
          );
          debugPrint('Startup: Launch at startup configured');
        }
      } catch (e) {
        debugPrint('Launch at startup setup failed: $e');
      }

      runApp(const BreakLoopApp());
      debugPrint('Startup: app running');
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
