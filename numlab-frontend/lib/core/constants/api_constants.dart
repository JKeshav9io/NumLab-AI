import 'package:flutter/foundation.dart';

/// Centralized API and Network Constants.
///
/// Base URL resolution:
/// Reads `--dart-define=API_BASE_URL=...` at compile time.
/// If omitted, falls back dynamically:
/// - Android physical device / emulator: `http://10.0.2.2:3000/api/v1` for emulator
/// - Web / Desktop / iOS Simulator: `http://localhost:3000/api/v1`
abstract final class ApiConstants {
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get defaultBaseUrl {
    if (_envBaseUrl.isNotEmpty) {
      return _envBaseUrl;
    }

    // Smart developer fallbacks:
    if (kIsWeb) {
      return 'http://localhost:3000/api/v1';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Android emulator loopback to host machine
        return 'http://10.0.2.2:3000/api/v1';
      case TargetPlatform.iOS:
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return 'http://localhost:3000/api/v1';
    }
  }

  // Network Timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
  static const Duration sendTimeout = Duration(seconds: 15);

  // Common Headers
  static const String authHeader = 'Authorization';
  static const String bearerPrefix = 'Bearer ';

  // Route paths
  static const String registerPath = '/auth/register';
  static const String loginPath = '/auth/login';
  static const String refreshPath = '/auth/refresh';
  static const String logoutPath = '/auth/logout';
  static const String logoutAllPath = '/auth/logout-all';
  static const String userMePath = '/users/me';
  static const String historyPath = '/users/me/history';
  static const String explainPath = '/explain';
  static const String reportsPath = '/reports';
}
