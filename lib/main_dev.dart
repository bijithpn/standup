import 'package:breakmate/core/config/flavor_config.dart';
import 'package:breakmate/main_common.dart';

export 'package:breakmate/main_common.dart' show overlayMain, companionMain;

void main() {
  FlavorConfig(
    appName: 'BreakMate Dev',
    bundleId: 'com.bijith.breakmate.dev',
    flavorType: FlavorType.dev,
    sentryDsn: 'DEV_DSN_HERE',
  );
  mainCommon(FlavorConfig.instance);
}
