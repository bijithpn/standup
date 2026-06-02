import 'package:breakmate/core/config/flavor_config.dart';
import 'package:breakmate/main_common.dart';

export 'package:breakmate/main_common.dart' show overlayMain, companionMain;

void main() {
  FlavorConfig(
    appName: 'BreakMate',
    bundleId: 'com.bijith.breakmate',
    flavorType: FlavorType.prod,
    sentryDsn: 'https://3287665b86c8b294c6dbb5fead66c05b@o4511460809637888.ingest.de.sentry.io/4511460813963344',
  );
  mainCommon(FlavorConfig.instance);
}
