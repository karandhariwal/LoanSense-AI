/// profile_providers.dart
///
/// Riverpod providers for user profile and settings.
/// Uses HttpUserProfileRepository for all API calls.
///
/// Provider graph:
///   userProfileRepositoryProvider  →  HttpUserProfileRepository
///   profileProvider                →  AsyncNotifier<ProfileSettingsState>
///   profileSettingsNotifierProvider → alias to profileProvider

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loansense_ai/data/models/user_profile_model.dart';
import 'package:loansense_ai/data/repositories/http_user_profile_repository.dart';
import 'package:loansense_ai/data/repositories/user_profile_repository.dart';
import 'package:loansense_ai/presentation/providers/loan_providers.dart';

// ---------------------------------------------------------------------------
// Repository provider
// ---------------------------------------------------------------------------

/// Provides the [IUserProfileRepository] implementation.
/// Swapping mock ↔ HTTP only requires changing this one line.
final userProfileRepositoryProvider = Provider<IUserProfileRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return HttpUserProfileRepository(apiClient: client);
});

// ---------------------------------------------------------------------------
// Combined profile + settings state
// ---------------------------------------------------------------------------

/// AsyncNotifier that manages [ProfileSettingsState].
/// Loads profile + settings concurrently on init.
/// Exposes mutators for profile and settings updates that refresh state
/// immediately (optimistic) and then confirm from API response.
class ProfileSettingsNotifier
    extends AsyncNotifier<ProfileSettingsState> {
  IUserProfileRepository get _repo =>
      ref.read(userProfileRepositoryProvider);

  @override
  Future<ProfileSettingsState> build() async {
    return _fetchBoth();
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  Future<ProfileSettingsState> _fetchBoth() async {
    // Parallel fetch — both calls happen simultaneously
    final results = await Future.wait([
      _repo.fetchProfile(),
      _repo.fetchSettings(),
    ]);
    return ProfileSettingsState(
      profile: results[0] as UserProfile,
      settings: results[1] as AppSettings,
    );
  }

  // ── Public API ───────────────────────────────────────────────────────────

  /// Reload profile + settings from the API (e.g. pull-to-refresh).
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetchBoth);
  }

  /// PATCH /user/profile — update profile fields, refresh state immediately.
  Future<void> updateProfile(UserProfile updated) async {
    // Optimistic update: reflect changes in UI instantly
    final prev = state.valueOrNull;
    if (prev != null) {
      state = AsyncValue.data(prev.copyWith(profile: updated));
    }

    state = await AsyncValue.guard(() async {
      final confirmed = await _repo.updateProfile(updated);
      final current = state.valueOrNull ?? ProfileSettingsState.initial();
      return current.copyWith(profile: confirmed);
    });
  }

  /// PATCH /user/settings — update settings, refresh state immediately.
  Future<void> updateSettings(AppSettings updated) async {
    // Optimistic update
    final prev = state.valueOrNull;
    if (prev != null) {
      state = AsyncValue.data(prev.copyWith(settings: updated));
    }

    state = await AsyncValue.guard(() async {
      final confirmed = await _repo.updateSettings(updated);
      final current = state.valueOrNull ?? ProfileSettingsState.initial();
      return current.copyWith(settings: confirmed);
    });
  }

  /// DELETE /user/documents
  Future<void> deleteUploadedDocuments() async {
    await _repo.deleteUploadedDocuments();
  }

  /// POST /auth/logout
  Future<void> signOut() async {
    await _repo.signOut();
  }
}

/// The main provider. Use [profileSettingsProvider] to watch/read state.
final profileSettingsProvider =
    AsyncNotifierProvider<ProfileSettingsNotifier, ProfileSettingsState>(
  ProfileSettingsNotifier.new,
);
