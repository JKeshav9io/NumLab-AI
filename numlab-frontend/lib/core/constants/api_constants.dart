import 'package:flutter/foundation.dart';

/// Centralized API and Network Constants.
///
/// Base URL resolution:
/// 1. Reads `--dart-define=API_BASE_URL=...` at compile time (or from `.env`).
/// 2. Reads `--dart-define=API_HOST=...` or `--dart-define=HOST_IP=...` if provided.
/// 3. If `--dart-define=IS_PHYSICAL_DEVICE=true` or `--dart-define=PHYSICAL_DEVICE=true` is set on Android,
///    targets the physical host LAN IP (`http://192.168.1.36:3000/api/v1`).
/// 4. If omitted, falls back dynamically:
///    - Android emulator loopback: `http://10.0.2.2:3000/api/v1`
///    - Web / Desktop / iOS Simulator: `http://localhost:3000/api/v1`
abstract final class ApiConstants {
  // Compile-time environment variable overrides
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _envHost = String.fromEnvironment('API_HOST');
  static const String _envHostIp = String.fromEnvironment('HOST_IP');
  static const bool _isPhysicalDevice =
      bool.fromEnvironment('IS_PHYSICAL_DEVICE');
  static const bool _isPhysical = bool.fromEnvironment('PHYSICAL_DEVICE');

  // Network Host & Port Constants
  static const String physicalDeviceHost = '192.168.1.36';
  static const String emulatorHost = '10.0.2.2';
  static const String localhostHost = 'localhost';
  static const int defaultPort = 3000;
  static const String apiPrefix = '/api/v1';

  // Standard Environment URLs
  static const String physicalDeviceBaseUrl =
      'http://$physicalDeviceHost:$defaultPort$apiPrefix';
  static const String emulatorBaseUrl =
      'http://$emulatorHost:$defaultPort$apiPrefix';
  static const String localhostBaseUrl =
      'http://$localhostHost:$defaultPort$apiPrefix';

  /// Primary Base URL getter used across network client configurations.
  static String get defaultBaseUrl {
    if (_envBaseUrl.isNotEmpty) {
      return _envBaseUrl;
    }

    if (_envHost.isNotEmpty) {
      return 'http://$_envHost:$defaultPort$apiPrefix';
    }

    if (_envHostIp.isNotEmpty) {
      return 'http://$_envHostIp:$defaultPort$apiPrefix';
    }

    // Smart developer fallbacks:
    if (kIsWeb) {
      return localhostBaseUrl;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        if (_isPhysicalDevice || _isPhysical) {
          return physicalDeviceBaseUrl;
        }
        // Android emulator loopback to host machine
        return emulatorBaseUrl;
      case TargetPlatform.iOS:
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return localhostBaseUrl;
    }
  }

  /// Alias for [defaultBaseUrl] aligning with codebase conventions.
  static String get baseUrl => defaultBaseUrl;

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
