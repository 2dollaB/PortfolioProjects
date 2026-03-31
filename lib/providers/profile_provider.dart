import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../services/storage_service.dart';

/// Async notifier for user profile state
/// Loads from local storage, syncs to Firestore when available
class ProfileNotifier extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() async {
    return StorageService.loadProfile();
  }

  /// Save/update profile
  Future<void> updateProfile(UserProfile profile) async {
    await StorageService.saveProfile(profile);
    state = AsyncData(profile);
  }

  /// Quick profile creation (minimal fields for fast onboarding)
  Future<void> quickSetup({
    required String name,
    required int age,
    required Sex sex,
    required double weightKg,
    required double heightCm,
    UserRole role = UserRole.athlete,
  }) async {
    final profile = UserProfile(
      name: name,
      age: age,
      sex: sex,
      weightKg: weightKg,
      heightCm: heightCm,
      role: role,
    );
    await updateProfile(profile);
  }

  /// Update dynamic HR max after workout
  void updateDynamicHrMax(int observedMax) {
    final current = state.valueOrNull;
    if (current == null) return;
    current.updateDynamicHrMax(observedMax);
    state = AsyncData(current);
  }

  /// Clear profile (logout / reset)
  Future<void> clearProfile() async {
    await StorageService.resetAllData();
    state = const AsyncData(null);
  }
}

final profileProvider =
    AsyncNotifierProvider<ProfileNotifier, UserProfile?>(ProfileNotifier.new);

/// Convenience: whether user has completed profile setup
final hasProfileProvider = Provider<bool>((ref) {
  return ref.watch(profileProvider).valueOrNull != null;
});

/// Convenience: current user role
final userRoleProvider = Provider<UserRole?>((ref) {
  return ref.watch(profileProvider).valueOrNull?.role;
});
