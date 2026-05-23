// ---------------------------------------------------------------------------
// PROFİL DURUM YÖNETİMİ (RIVERPOD)
// ---------------------------------------------------------------------------
// Profil ekranının verisini Riverpod ile yönetir: yükleme, yenileme, profil
// güncelleme ve profil fotoğrafı yükleme işlemleri buradan yürür.
// ---------------------------------------------------------------------------

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/api_servisi.dart';
import '../../../shared/models/profil_model.dart';

/// Profil işlemleri için kullanılan API servisini sağlar.
final profilApiProvider = Provider<ApiServisi>((ref) => ApiServisi());

/// Başka bir kullanıcının profilini id ile yükler (salt-okunur görünüm).
final idIleProfilProvider = FutureProvider.autoDispose.family<ProfilModel, int>(
  (ref, userId) {
    return ref.watch(profilApiProvider).idIleProfilGetir(userId);
  },
);

/// Oturum sahibinin kendi profilini yöneten ana provider.
///
/// Oluşturulduğunda profili otomatik yükler; ekran bu provider'ı izleyerek
/// yükleme/veri/hata durumlarına göre kendini günceller.
final profilProvider =
    StateNotifierProvider.autoDispose<
      ProfilDenetleyici,
      AsyncValue<ProfilModel>
    >((ref) {
      final notifier = ProfilDenetleyici(ref.watch(profilApiProvider));
      notifier.loadProfile();
      return notifier;
    });

/// Profil verisinin yüklenmesini ve güncellenmesini yöneten kontrolcü.
class ProfilDenetleyici extends StateNotifier<AsyncValue<ProfilModel>> {
  final ApiServisi _api;

  ProfilDenetleyici(this._api) : super(const AsyncValue.loading());

  /// Profili sunucudan ilk kez yükler (önce yükleme durumuna geçer).
  Future<void> loadProfile() async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(_api.profiliGetir);
    if (mounted) state = result;
  }

  /// Yenileme sırasında mevcut profil verisini ekranda tutar; böylece
  /// pull-to-refresh'te içerik aniden shimmer'a dönüşmez.
  Future<void> refresh() async {
    final result = await AsyncValue.guard(_api.profiliGetir);
    if (mounted) state = result;
  }

  /// Profil bilgilerini günceller ve dönen yeni profili duruma yazar.
  Future<void> profiliGuncellee(Map<String, dynamic> data) async {
    final updatedProfile = await _api.profiliGuncelle(data);
    if (mounted) state = AsyncValue.data(updatedProfile);
  }

  /// Yeni profil fotoğrafını yükler ve dönen güncel profili duruma yazar.
  Future<void> uploadProfilePhoto(XFile photo) async {
    final updatedProfile = await _api.profilFotoYukle(photo);
    if (mounted) state = AsyncValue.data(updatedProfile);
  }
}
