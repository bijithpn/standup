import 'dart:io';
import 'package:flutter/material.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:standup/app/app.dart';
import 'package:standup/app/dependency_injection.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Single instance check via Socket
    try {
      await ServerSocket.bind('127.0.0.1', 10425);
    } catch (_) {
      // Port already in use -> another instance running
      exit(0);
    }

    // Initialize all dependencies first
    await initDependencies();

    // Initialize Window Manager
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(500, 700),
      center: true,
      backgroundColor: Colors.black, // Opaque for stability
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setPreventClose(true);
      await windowManager.hide();
    });

    // Setup Launch at Startup (optional, can fail if no info)
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

    runApp(const BreakLoopApp());
  } catch (e, stack) {
    debugPrint('FATAL STARTUP ERROR: $e');
    debugPrint(stack.toString());
    // Fallback to minimal app if possible to show error? 
    // For now, just crash safely.
  }
}
