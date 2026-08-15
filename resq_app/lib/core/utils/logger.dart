import 'package:flutter/foundation.dart';

class AppLogger {
  static void info(String message, [String tag = 'ResQ']) {
    if (kDebugMode) {
      print('ℹ️ [$tag] $message');
    }
  }

  static void debug(String message, [String tag = 'ResQ']) {
    if (kDebugMode) {
      print('🔍 [$tag] $message');
    }
  }

  static void warning(String message, [String tag = 'ResQ']) {
    if (kDebugMode) {
      print('⚠️ [$tag] $message');
    }
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace, String tag = 'ResQ']) {
    if (kDebugMode) {
      print('❌ [$tag] ERROR: $message');
      if (error != null) print('Detail: $error');
      if (stackTrace != null) print(stackTrace);
    }
  }
}
