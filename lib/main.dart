import 'package:breakmate/main_prod.dart' as prod;
import 'package:breakmate/main_dev.dart' as dev;
import 'package:flutter/foundation.dart';

export 'package:breakmate/main_common.dart' show overlayMain, companionMain;

void main() {
  if (kDebugMode) {
    dev.main();
  } else {
    prod.main();
  }
}
