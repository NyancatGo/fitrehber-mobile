import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/api_service.dart';
import '../../../shared/models/profil_model.dart';

final profileApiProvider = Provider<ApiService>((ref) => ApiService());

/// Başka bir kullanıcının profilini id ile yükler (salt-okunur görünüm).
final profileByIdProvider = FutureProvider.autoDispose.family<ProfilModel, int>(
  (ref, userId) {
    return ref.watch(profileApiProvider).getProfilById(userId);
  },
);

final profileProvider =
    StateNotifierProvider.autoDispose<ProfileNotifier, AsyncValue<ProfilModel>>(
      (ref) {
        final notifier = ProfileNotifier(ref.watch(profileApiProvider));
        notifier.loadProfile();
        return notifier;
      },
    );

class ProfileNotifier extends StateNotifier<AsyncValue<ProfilModel>> {
  final ApiService _api;

  ProfileNotifier(this._api) : super(const AsyncValue.loading());

  Future<void> loadProfile() async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(_api.getProfil);
    if (mounted) state = result;
  }

  Future<void> refresh() => loadProfile();

  Future<void> updateProfile(Map<String, dynamic> data) async {
    final updatedProfile = await _api.updateProfil(data);
    if (mounted) state = AsyncValue.data(updatedProfile);
  }

  Future<void> uploadProfilePhoto(XFile photo) async {
    final updatedProfile = await _api.profilFotoYukle(photo);
    if (mounted) state = AsyncValue.data(updatedProfile);
  }
}
