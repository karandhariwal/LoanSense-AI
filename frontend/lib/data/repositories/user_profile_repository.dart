/// user_profile_repository.dart
/// Scalable repository for user profile and settings.
/// Uses mock data now; swap service calls for real API later.

import 'dart:async';
import 'package:loansense_ai/data/models/user_profile_model.dart';

// ---------------------------------------------------------------------------
// Abstract contract — easy to swap for real implementation
// ---------------------------------------------------------------------------

abstract class IUserProfileRepository {
  Future<UserProfile> fetchProfile();
  Future<AppSettings> fetchSettings();
  Future<UserProfile> updateProfile(UserProfile updated);
  Future<AppSettings> updateSettings(AppSettings updated);
  Future<void> deleteUploadedDocuments();
  Future<void> signOut();
}

// ---------------------------------------------------------------------------
// Mock implementation — simulates async API latency
// ---------------------------------------------------------------------------

class MockUserProfileRepository implements IUserProfileRepository {
  // In-memory store
  UserProfile _profile = UserProfile.mock();
  AppSettings _settings = AppSettings.defaults();

  @override
  Future<UserProfile> fetchProfile() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _profile;
  }

  @override
  Future<AppSettings> fetchSettings() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _settings;
  }

  @override
  Future<UserProfile> updateProfile(UserProfile updated) async {
    await Future.delayed(const Duration(milliseconds: 600));
    _profile = updated.copyWith(updatedAt: DateTime.now());
    return _profile;
  }

  @override
  Future<AppSettings> updateSettings(AppSettings updated) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _settings = updated;
    return _settings;
  }

  @override
  Future<void> deleteUploadedDocuments() async {
    await Future.delayed(const Duration(milliseconds: 800));
    // In production: call DELETE /api/user/documents
  }

  @override
  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 300));
    // In production: call POST /api/auth/logout + clear tokens
  }
}

// ---------------------------------------------------------------------------
// Singleton accessor (replace with DI / provider later)
// ---------------------------------------------------------------------------

class UserProfileRepositoryProvider {
  static final IUserProfileRepository instance = MockUserProfileRepository();
}
