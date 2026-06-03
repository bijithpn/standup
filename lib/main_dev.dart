import 'package:breakmate/core/config/flavor_config.dart';
import 'package:breakmate/main_common.dart' as common;

@pragma('vm:entry-point')
void overlayMain() {
  common.overlayMain();
}

@pragma('vm:entry-point')
void companionMain() {
  common.companionMain();
}

void main() {
  FlavorConfig(
    appName: 'BreakMate Dev',
    bundleId: 'com.bijith.breakmate.dev',
    flavorType: FlavorType.dev,
    sentryDsn: 'DEV_DSN_HERE',
  );
  common.mainCommon(FlavorConfig.instance);
}
