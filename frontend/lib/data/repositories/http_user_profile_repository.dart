/// HTTP-based User Profile Repository - uses real backend API calls
/// Replaces mock data with actual real-time API communication

import 'package:loansense_ai/core/network/api_client.dart';
import 'package:loansense_ai/data/models/user_profile_model.dart';
import 'package:loansense_ai/core/error/exceptions.dart';
import 'package:loansense_ai/data/repositories/user_profile_repository.dart';

/// Real HTTP implementation that calls backend API
class HttpUserProfileRepository implements IUserProfileRepository {
  final ApiClient _apiClient;

  HttpUserProfileRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Fetch user profile from backend API
  /// GET /api/v1/user/profile
  @override
  Future<UserProfile> fetchProfile() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>('/user/profile');
      
      if (response.data == null) {
        throw const ApiException(message: 'Profile response returned empty data');
      }
      
      // Parse JSON response to UserProfile model
      return UserProfile.fromJson(response.data!);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: 'Failed to fetch profile: ${e.toString()}');
    }
  }

  /// Fetch app settings from backend API
  /// GET /api/v1/user/settings
  @override
  Future<AppSettings> fetchSettings() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>('/user/settings');
      
      if (response.data == null) {
        throw const ApiException(message: 'Settings response returned empty data');
      }
      
      return AppSettings.fromJson(response.data!);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: 'Failed to fetch settings: ${e.toString()}');
    }
  }

  /// Update user profile via backend API
  /// PATCH /api/v1/user/profile
  @override
  Future<UserProfile> updateProfile(UserProfile updated) async {
    try {
      final response = await _apiClient.patch<Map<String, dynamic>>(
        '/user/profile',
        data: updated.toJson(),
      );
      
      if (response.data == null) {
        throw const ApiException(message: 'Update profile response returned empty data');
      }
      
      return UserProfile.fromJson(response.data!);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: 'Failed to update profile: ${e.toString()}');
    }
  }

  /// Update app settings via backend API
  /// PATCH /api/v1/user/settings
  @override
  Future<AppSettings> updateSettings(AppSettings updated) async {
    try {
      final response = await _apiClient.patch<Map<String, dynamic>>(
        '/user/settings',
        data: updated.toJson(),
      );
      
      if (response.data == null) {
        throw const ApiException(message: 'Update settings response returned empty data');
      }
      
      return AppSettings.fromJson(response.data!);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: 'Failed to update settings: ${e.toString()}');
    }
  }

  /// Delete uploaded documents via backend API
  /// DELETE /api/v1/user/documents
  @override
  Future<void> deleteUploadedDocuments() async {
    try {
      await _apiClient.delete<void>('/user/documents');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: 'Failed to delete documents: ${e.toString()}');
    }
  }

  /// Sign out user via backend API
  /// POST /api/v1/auth/logout (clears session/token on server)
  @override
  Future<void> signOut() async {
    try {
      await _apiClient.post<void>('/auth/logout');
      // Local token cleanup should happen in the auth provider/service
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: 'Failed to sign out: ${e.toString()}');
    }
  }
}
