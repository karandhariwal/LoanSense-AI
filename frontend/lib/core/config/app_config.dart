import 'package:flutter/foundation.dart';

/// Application Configuration Management
/// This replaces hardcoded values with environment-based configuration

abstract class AppConfig {
  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static bool get hasApiBaseUrlOverride => _apiBaseUrlOverride.isNotEmpty;

  /// API Base URL - change this based on environment
  static String get apiBaseUrl =>
      hasApiBaseUrlOverride ? _apiBaseUrlOverride : developmentUrl;
  
  /// Available environments
  static String get developmentUrl => developmentUrls.first;

  static List<String> get developmentUrls => _getLocalHostsForEnvironment()
      .map((host) => 'http://$host:8000')
      .toList(growable: false);

  static const String stagingUrl = 'https://staging-api.loansense.example.com';
  static const String productionUrl = 'https://api.loansense.example.com';
  
  /// Network timeouts (in seconds)
  static const int connectTimeout = 30;
  // LLM comparison pipeline can take up to 60s+; set generous receive timeout
  static const int receiveTimeout = 180;
  static const int sendTimeout = 60;
  
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

List<String> _getLocalHostsForEnvironment() {
  if (kIsWeb) {
    return const ['localhost', '127.0.0.1'];
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      // For a physical Android device with `adb reverse tcp:8000 tcp:8000`,
      // 127.0.0.1 on the phone tunnels to the PC's localhost. Try it first.
      // 10.0.2.2 is the Android emulator bridge — try it second.
      return const ['127.0.0.1', '10.0.2.2', 'localhost'];
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
      return const ['localhost', '127.0.0.1'];
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
    if (AppConfig.hasApiBaseUrlOverride) {
      return AppConfig.apiBaseUrl;
    }

    return AppConfig.getApiUrl(environment: environmentName);
  }

  static List<String> get apiUrls {
    if (AppConfig.hasApiBaseUrlOverride) {
      return [AppConfig.apiBaseUrl];
    }

    if (isDevelopment) {
      return AppConfig.developmentUrls;
    }

    return [AppConfig.getApiUrl(environment: environmentName)];
  }

  static bool get isProduction => currentFlavor == BuildFlavor.production;
  static bool get isStaging => currentFlavor == BuildFlavor.staging;
  static bool get isDevelopment => currentFlavor == BuildFlavor.development;
}
