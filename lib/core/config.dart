import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

class AppConfig {
  static const appName = 'Expensify';
  static const assistantName = 'xp';

  /// Set for release builds: flutter build appbundle --dart-define=API_URL=https://your-api.example.com
  static const _apiUrlOverride = String.fromEnvironment('API_URL');

  /// Android emulators reach the host machine through 10.0.2.2, not localhost.
  static String get apiBaseUrl {
    if (_apiUrlOverride.isNotEmpty) return _apiUrlOverride;
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:4000';
    return 'http://localhost:4000';
  }

  static const privacyPolicyUrl = String.fromEnvironment(
    'PRIVACY_URL',
    defaultValue: 'https://example.com/privacy',
  );
}
