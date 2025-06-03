import 'package:flutter/foundation.dart';

class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  bool _isEnabled = true;
  bool get isEnabled => _isEnabled;
  set isEnabled(bool value) => _isEnabled = value;

  void log(String message, {String? tag, bool forceShow = false}) {
    if (!_isEnabled && !forceShow) return;
    if (kDebugMode) {
      final timestamp = DateTime.now().toString().split('.').first;
      final tagStr = tag != null ? '[$tag] ' : '';
      debugPrint('$timestamp $tagStr$message');
    }
  }

  void debug(String message, {String? tag}) {
    log(message, tag: tag ?? 'DEBUG');
  }

  void info(String message, {String? tag}) {
    log(message, tag: tag ?? 'INFO');
  }

  void warning(String message, {String? tag}) {
    log('⚠️ $message', tag: tag ?? 'WARN', forceShow: true);
  }

  void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    log('❌ $message${error != null ? '\nError: $error' : ''}${stackTrace != null ? '\nStack: $stackTrace' : ''}',
      tag: tag ?? 'ERROR',
      forceShow: true
    );
  }

  void success(String message, {String? tag}) {
    log('✅ $message', tag: tag ?? 'SUCCESS');
  }
} 