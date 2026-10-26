import 'package:breakmate/main_prod.dart' as prod;
import 'package:breakmate/main_dev.dart' as dev;
import 'package:flutter/foundation.dart';
import 'package:breakmate/main_common.dart' as common;

@pragma('vm:entry-point')
void overlayMain() {
  common.overlayMain();
}

@pragma('vm:entry-point')
void companionMain() {
  common.companionMain();
}

@pragma('vm:entry-point')
void pipMain() {
  common.pipMain();
}

void main(List<String> args) {
  if (kDebugMode) {
    dev.main(args);
  } else {
    prod.main(args);
  }
}
