import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile_model.dart';
import '../services/profile_service.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class ProfileState {
  final UserProfileModel? profile;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final String? saveErrorMessage;

  const ProfileState({
    this.profile,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.saveErrorMessage,
  });

  ProfileState copyWith({
    UserProfileModel? profile,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    String? saveErrorMessage,
    bool clearSaveError = false,
    bool clearError = false,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      saveErrorMessage: clearSaveError
          ? null
          : (saveErrorMessage ?? this.saveErrorMessage),
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final profileControllerProvider =
    NotifierProvider<ProfileController, ProfileState>(
  ProfileController.new,
);

// ── Controller ────────────────────────────────────────────────────────────────

class ProfileController extends Notifier<ProfileState> {
  @override
  ProfileState build() {
    Future.microtask(() => fetchProfile());
    return const ProfileState(isLoading: true);
  }

  Future<void> fetchProfile() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final service = ref.read(profileServiceProvider);
      final profile = await service.fetchProfile();
      state = state.copyWith(profile: profile, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// Sends only fields that differ from the server-stored profile.
  Future<bool> saveProfile({
    required String name,
    required String preferredUnit,
    required double? weightKg,
    required double? heightCm,
    required String? fitnessGoal,
    required String? experienceLevel,
    required String? injuriesOrLimitations,
  }) async {
    state = state.copyWith(isSaving: true, clearSaveError: true);
    try {
      final service = ref.read(profileServiceProvider);
      final updated = await service.updateProfile(
        name: name.trim(),
        preferredUnit: preferredUnit,
        weightKg: weightKg,
        heightCm: heightCm,
        fitnessGoal: fitnessGoal,
        experienceLevel: experienceLevel,
        injuriesOrLimitations: injuriesOrLimitations,
      );
      state = state.copyWith(profile: updated, isSaving: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        saveErrorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }
}
