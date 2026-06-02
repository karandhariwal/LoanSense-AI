/// user_profile_model.dart
/// Data models for the Profile & Settings screen.
/// Fully JSON-serialisable and backend-ready.

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum AppThemeMode { dark, light }

enum AiResponseStyle { precise, balanced, analytical }

enum AppLanguage { english, hindi, spanish, french, german }

extension AppLanguageExtension on AppLanguage {
  String get displayName {
    switch (this) {
      case AppLanguage.english:
        return 'English (US)';
      case AppLanguage.hindi:
        return 'Hindi';
      case AppLanguage.spanish:
        return 'Spanish';
      case AppLanguage.french:
        return 'French';
      case AppLanguage.german:
        return 'German';
    }
  }

  String get code {
    switch (this) {
      case AppLanguage.english:
        return 'en_US';
      case AppLanguage.hindi:
        return 'hi_IN';
      case AppLanguage.spanish:
        return 'es_ES';
      case AppLanguage.french:
        return 'fr_FR';
      case AppLanguage.german:
        return 'de_DE';
    }
  }

  static AppLanguage fromCode(String code) {
    return AppLanguage.values.firstWhere(
      (l) => l.code == code,
      orElse: () => AppLanguage.english,
    );
  }
}

// ---------------------------------------------------------------------------
// UserProfile
// ---------------------------------------------------------------------------

class UserProfile {
  final String id;
  final String displayName;
  final String email;
  final String? phoneNumber;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.displayName,
    required this.email,
    this.phoneNumber,
    this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  UserProfile copyWith({
    String? id,
    String? displayName,
    String? email,
    String? phoneNumber,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'email': email,
        'phoneNumber': phoneNumber,
        'avatarUrl': avatarUrl,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// Mock/demo user
  factory UserProfile.mock() => UserProfile(
        id: 'usr-lns-001',
        displayName: 'Alexander Vance',
        email: 'alexander.vance@financial-elite.com',
        phoneNumber: '+91 98765 43210',
        avatarUrl: null, // will use initials avatar
        createdAt: DateTime(2024, 1, 15),
        updatedAt: DateTime.now(),
      );
}

// ---------------------------------------------------------------------------
// NotificationSettings
// ---------------------------------------------------------------------------

class NotificationSettings {
  final bool pushEnabled;
  final bool emailEnabled;
  final bool riskAlerts;
  final bool weeklyDigest;
  final bool aiInsights;

  const NotificationSettings({
    this.pushEnabled = true,
    this.emailEnabled = true,
    this.riskAlerts = true,
    this.weeklyDigest = false,
    this.aiInsights = true,
  });

  NotificationSettings copyWith({
    bool? pushEnabled,
    bool? emailEnabled,
    bool? riskAlerts,
    bool? weeklyDigest,
    bool? aiInsights,
  }) {
    return NotificationSettings(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      riskAlerts: riskAlerts ?? this.riskAlerts,
      weeklyDigest: weeklyDigest ?? this.weeklyDigest,
      aiInsights: aiInsights ?? this.aiInsights,
    );
  }

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      pushEnabled: json['pushEnabled'] as bool? ?? true,
      emailEnabled: json['emailEnabled'] as bool? ?? true,
      riskAlerts: json['riskAlerts'] as bool? ?? true,
      weeklyDigest: json['weeklyDigest'] as bool? ?? false,
      aiInsights: json['aiInsights'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'pushEnabled': pushEnabled,
        'emailEnabled': emailEnabled,
        'riskAlerts': riskAlerts,
        'weeklyDigest': weeklyDigest,
        'aiInsights': aiInsights,
      };
}

// ---------------------------------------------------------------------------
// PrivacySettings
// ---------------------------------------------------------------------------

class PrivacySettings {
  final bool biometricLock;
  final bool dataCollectionOptIn;
  final bool crashReporting;
  final String dataRetentionDays; // e.g. "30 Days"

  const PrivacySettings({
    this.biometricLock = true,
    this.dataCollectionOptIn = false,
    this.crashReporting = true,
    this.dataRetentionDays = '30 Days',
  });

  PrivacySettings copyWith({
    bool? biometricLock,
    bool? dataCollectionOptIn,
    bool? crashReporting,
    String? dataRetentionDays,
  }) {
    return PrivacySettings(
      biometricLock: biometricLock ?? this.biometricLock,
      dataCollectionOptIn: dataCollectionOptIn ?? this.dataCollectionOptIn,
      crashReporting: crashReporting ?? this.crashReporting,
      dataRetentionDays: dataRetentionDays ?? this.dataRetentionDays,
    );
  }

  factory PrivacySettings.fromJson(Map<String, dynamic> json) {
    return PrivacySettings(
      biometricLock: json['biometricLock'] as bool? ?? true,
      dataCollectionOptIn: json['dataCollectionOptIn'] as bool? ?? false,
      crashReporting: json['crashReporting'] as bool? ?? true,
      dataRetentionDays: json['dataRetentionDays']?.toString() ?? '30 Days',
    );
  }

  Map<String, dynamic> toJson() => {
        'biometricLock': biometricLock,
        'dataCollectionOptIn': dataCollectionOptIn,
        'crashReporting': crashReporting,
        'dataRetentionDays': dataRetentionDays,
      };
}

// ---------------------------------------------------------------------------
// AppSettings — the top-level settings object
// ---------------------------------------------------------------------------

class AppSettings {
  final AppThemeMode themeMode;
  final AiResponseStyle aiResponseStyle;
  final AppLanguage language;
  final NotificationSettings notifications;
  final PrivacySettings privacy;
  final String appVersion;

  const AppSettings({
    this.themeMode = AppThemeMode.dark,
    this.aiResponseStyle = AiResponseStyle.balanced,
    this.language = AppLanguage.english,
    this.notifications = const NotificationSettings(),
    this.privacy = const PrivacySettings(),
    this.appVersion = 'v4.12.0-STABLE',
  });

  AppSettings copyWith({
    AppThemeMode? themeMode,
    AiResponseStyle? aiResponseStyle,
    AppLanguage? language,
    NotificationSettings? notifications,
    PrivacySettings? privacy,
    String? appVersion,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      aiResponseStyle: aiResponseStyle ?? this.aiResponseStyle,
      language: language ?? this.language,
      notifications: notifications ?? this.notifications,
      privacy: privacy ?? this.privacy,
      appVersion: appVersion ?? this.appVersion,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      themeMode: json['themeMode'] == 'light' ? AppThemeMode.light : AppThemeMode.dark,
      aiResponseStyle: _parseAiStyle(json['aiResponseStyle']?.toString()),
      language: AppLanguageExtension.fromCode(json['language']?.toString() ?? 'en_US'),
      notifications: json['notifications'] != null
          ? NotificationSettings.fromJson(json['notifications'] as Map<String, dynamic>)
          : const NotificationSettings(),
      privacy: json['privacy'] != null
          ? PrivacySettings.fromJson(json['privacy'] as Map<String, dynamic>)
          : const PrivacySettings(),
      appVersion: json['appVersion']?.toString() ?? 'v4.12.0-STABLE',
    );
  }

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode == AppThemeMode.light ? 'light' : 'dark',
        'aiResponseStyle': aiResponseStyle.name,
        'language': language.code,
        'notifications': notifications.toJson(),
        'privacy': privacy.toJson(),
        'appVersion': appVersion,
      };

  static AiResponseStyle _parseAiStyle(String? value) {
    switch (value) {
      case 'precise':
        return AiResponseStyle.precise;
      case 'analytical':
        return AiResponseStyle.analytical;
      default:
        return AiResponseStyle.balanced;
    }
  }

  factory AppSettings.defaults() => const AppSettings();
}

// ---------------------------------------------------------------------------
// ProfileSettingsState — combined view-model for the screen
// ---------------------------------------------------------------------------

class ProfileSettingsState {
  final UserProfile profile;
  final AppSettings settings;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  const ProfileSettingsState({
    required this.profile,
    required this.settings,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
  });

  ProfileSettingsState copyWith({
    UserProfile? profile,
    AppSettings? settings,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
  }) {
    return ProfileSettingsState(
      profile: profile ?? this.profile,
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage,
    );
  }

  factory ProfileSettingsState.initial() => ProfileSettingsState(
        profile: UserProfile.mock(),
        settings: AppSettings.defaults(),
        isLoading: false,
      );
}
