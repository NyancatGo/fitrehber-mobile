import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/api_service.dart';
import '../../../shared/models/beslenme_model.dart';

class NutritionState {
  final bool isLoading;
  final String? hata;
  final GunlukBeslenmeModel? veri;
  final String seciliTarih;

  NutritionState({
    this.isLoading = false,
    this.hata,
    this.veri,
    required this.seciliTarih,
  });

  NutritionState copyWith({
    bool? isLoading,
    String? hata,
    GunlukBeslenmeModel? veri,
    String? seciliTarih,
    bool clearHata = false,
    bool clearVeri = false,
  }) {
    return NutritionState(
      isLoading: isLoading ?? this.isLoading,
      hata: clearHata ? null : (hata ?? this.hata),
      veri: clearVeri ? null : (veri ?? this.veri),
      seciliTarih: seciliTarih ?? this.seciliTarih,
    );
  }
}

class NutritionNotifier extends StateNotifier<NutritionState> {
  final ApiService _api = ApiService();

  NutritionNotifier()
      : super(
          NutritionState(
            seciliTarih: _bugunStr(),
          ),
        ) {
    load(_bugunStr());
  }

  Future<void> load(String tarih) async {
    state = state.copyWith(
      isLoading: true,
      seciliTarih: tarih,
      clearHata: true,
    );
    try {
      final veri = await _api.getBeslenmeSu(tarih);
      state = state.copyWith(isLoading: false, veri: veri);
    } catch (e) {
      // API hazır olmadığında boş veri ile devam et.
      state = state.copyWith(
        isLoading: false,
        veri: GunlukBeslenmeModel(tarih: tarih),
        clearHata: true,
      );
    }
  }

  Future<void> suEkle(int ml) async {
    final onceki = state.veri;
    final tarih = state.seciliTarih;
    // Optimistik güncelleme: UI anında tepki versin.
    if (onceki != null) {
      state = state.copyWith(
        veri: onceki.copyWith(suMl: onceki.suMl + ml),
      );
    }
    try {
      final guncellendi = await _api.suEkle(tarih: tarih, miktarMl: ml);
      state = state.copyWith(veri: guncellendi);
    } catch (_) {
      // API başarısızsa optimistik güncellemeyi geri al.
      if (mounted) state = state.copyWith(veri: onceki);
    }
  }

  Future<void> kaloriEkle({
    required int kaloriKcal,
    double proteinG = 0,
    double karbonhidratG = 0,
    double yagG = 0,
  }) async {
    final onceki = state.veri;
    final tarih = state.seciliTarih;
    if (onceki != null) {
      state = state.copyWith(
        veri: onceki.copyWith(
          kaloriKcal: onceki.kaloriKcal + kaloriKcal,
          proteinG: onceki.proteinG + proteinG,
          karbonhidratG: onceki.karbonhidratG + karbonhidratG,
          yagG: onceki.yagG + yagG,
        ),
      );
    }
    try {
      final guncellendi = await _api.kaloriEkle(
        tarih: tarih,
        kaloriKcal: kaloriKcal,
        proteinG: proteinG,
        karbonhidratG: karbonhidratG,
        yagG: yagG,
      );
      state = state.copyWith(veri: guncellendi);
    } catch (_) {
      if (mounted) state = state.copyWith(veri: onceki);
    }
  }

  static String _bugunStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

final nutritionProvider =
    StateNotifierProvider<NutritionNotifier, NutritionState>((ref) {
  return NutritionNotifier();
});
