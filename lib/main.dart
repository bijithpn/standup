import 'package:breakmate/main_prod.dart' as prod;
import 'package:breakmate/main_dev.dart' as dev;
import 'package:flutter/foundation.dart';

void main() {
  if (kDebugMode) {
    dev.main();
  } else {
    prod.main();
  }
}
