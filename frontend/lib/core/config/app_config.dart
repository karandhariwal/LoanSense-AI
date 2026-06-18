import 'package:flutter/foundation.dart';

/// Application Configuration Management
/// This replaces hardcoded values with environment-based configuration

abstract class AppConfig {
  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// API Base URL - change this based on environment
  static String get apiBaseUrl =>
      _apiBaseUrlOverride.isNotEmpty ? _apiBaseUrlOverride : developmentUrl;
  
  /// Available environments
  static String get developmentUrl {
    final host = _getLocalHostForEnvironment();
    return 'http://$host:8000';
  }

  static const String stagingUrl = 'https://staging-api.loansense.example.com';
  static const String productionUrl = 'https://api.loansense.example.com';
  
  /// Network timeouts (in seconds)
  static const int connectTimeout = 30;
  static const int receiveTimeout = 30;
  static const int sendTimeout = 30;
  
  /// API request configuration
  static const bool enableApiLogging = true;
  static const bool validateSSL = true; // Set to false only for development
  
  /// Security
  static const String tokenStorageKey = 'auth_token';
  static const String userStorageKey = 'user_data';
  
  /// Feature Flags
  static const bool enableOfflineMode = false;
  static const bool enableAnalytics = true;
  
  /// Set API environment - call this at app startup based on build flavor
  static String getApiUrl({required String environment}) {
    switch (environment.toLowerCase()) {
      case 'production':
        return productionUrl;
      case 'staging':
        return stagingUrl;
      case 'development':
      default:
        return developmentUrl;
    }
  }
}

String _getLocalHostForEnvironment() {
  if (kIsWeb) {
    return 'localhost';
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      // For physical device: run `adb reverse tcp:8000 tcp:8000` to tunnel
      // localhost on the device to your PC's port 8000.
      // For emulator only (no adb reverse needed): use '10.0.2.2' instead.
      return 'localhost';
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
      return 'localhost';
  }
}

/// Build flavor detection - helps determine environment at runtime
enum BuildFlavor {
  development,
  staging,
  production,
}

class BuildConfig {
  static BuildFlavor? _currentFlavor;

  static BuildFlavor get currentFlavor {
    _currentFlavor ??= BuildFlavor.development; // Default to development
    return _currentFlavor!;
  }

  static void setFlavor(BuildFlavor flavor) {
    _currentFlavor = flavor;
  }

  static String get environmentName {
    switch (currentFlavor) {
      case BuildFlavor.development:
        return 'development';
      case BuildFlavor.staging:
        return 'staging';
      case BuildFlavor.production:
        return 'production';
    }
  }

  static String get apiUrl {
    return AppConfig.getApiUrl(environment: environmentName);
  }

  static bool get isProduction => currentFlavor == BuildFlavor.production;
  static bool get isStaging => currentFlavor == BuildFlavor.staging;
  static bool get isDevelopment => currentFlavor == BuildFlavor.development;
}

