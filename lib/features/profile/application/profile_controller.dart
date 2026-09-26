import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../auth/application/app_session_controller.dart';
import '../domain/profile_input_validator.dart';
import '../domain/profile_repository.dart';

sealed class ProfileActionState {
  const ProfileActionState();
}

final class ProfileIdle extends ProfileActionState {
  const ProfileIdle();
}

final class ProfileSaving extends ProfileActionState {
  const ProfileSaving();
}

final class ProfileFailure extends ProfileActionState {
  const ProfileFailure(this.error);
  final AppError error;
}

class ProfileController extends Notifier<ProfileActionState> {
  @override
  ProfileActionState build() => const ProfileIdle();

  Future<void> refresh() async {
    final repository = ref.read(profileRepositoryProvider);
    if (repository == null) return;
    try {
      final profile = await repository.fetchOwnProfile();
      if (profile != null) {
        ref.read(appSessionControllerProvider.notifier).setProfile(profile);
      }
      state = const ProfileIdle();
    } on AppError catch (error) {
      state = ProfileFailure(error);
    }
  }

  Future<bool> save(String username, String avatarId) async {
    if (state is ProfileSaving) return false;
    final repository = ref.read(profileRepositoryProvider);
    if (repository == null) return false;
    late final ValidatedProfileInput input;
    try {
      input = ProfileInputValidator.validate(
        username: username,
        avatarId: avatarId,
      );
      state = const ProfileSaving();
      final profile = await repository.updateProfile(
        username: input.username,
        avatarId: input.avatarId,
      );
      ref.read(appSessionControllerProvider.notifier).setProfile(profile);
      state = const ProfileIdle();
      return true;
    } on NetworkAppError catch (error) {
      // The write may have reached the server even when its response was lost.
      // Re-read the authoritative row before presenting a retry that could
      // otherwise obscure a successful save.
      try {
        final profile = await repository.fetchOwnProfile();
        if (profile != null &&
            profile.username == input.username &&
            profile.avatarId == input.avatarId) {
          ref.read(appSessionControllerProvider.notifier).setProfile(profile);
          state = const ProfileIdle();
          return true;
        }
      } on AppError {
        // Preserve the original network failure below.
      }
      state = ProfileFailure(error);
      return false;
    } on AppError catch (error) {
      state = ProfileFailure(error);
      return false;
    }
  }
}

final profileControllerProvider =
    NotifierProvider<ProfileController, ProfileActionState>(
      ProfileController.new,
    );
