import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/api_service.dart';
import '../../../shared/models/beslenme_model.dart';
import '../../../shared/session_controller.dart';
import '../../../shared/utils/nutrition_calculator.dart';

class NutritionState {
  final bool isLoading;
  final String? hata;
  final GunlukBeslenmeModel? veri;
  final String seciliTarih;
  final NutritionGoals hedefler;

  NutritionState({
    this.isLoading = false,
    this.hata,
    this.veri,
    required this.seciliTarih,
    this.hedefler = NutritionGoals.defaults,
  });

  NutritionState copyWith({
    bool? isLoading,
    String? hata,
    GunlukBeslenmeModel? veri,
    String? seciliTarih,
    NutritionGoals? hedefler,
    bool clearHata = false,
    bool clearVeri = false,
  }) {
    return NutritionState(
      isLoading: isLoading ?? this.isLoading,
      hata: clearHata ? null : (hata ?? this.hata),
      veri: clearVeri ? null : (veri ?? this.veri),
      seciliTarih: seciliTarih ?? this.seciliTarih,
      hedefler: hedefler ?? this.hedefler,
    );
  }
}

class NutritionNotifier extends StateNotifier<NutritionState> {
  final ApiService _api = ApiService();
  final Ref _ref;

  NutritionNotifier(this._ref)
      : super(NutritionState(seciliTarih: _bugunStr())) {
    _hesaplaHedefler();
    load(_bugunStr());
  }

  /// Profil verilerinden dinamik hedefleri hesaplar.
  void _hesaplaHedefler() {
    final session = _ref.read(sessionControllerProvider);
    final profil = session.profile;
    final hedefler = NutritionCalculator.calculate(profil);
    state = state.copyWith(hedefler: hedefler);
  }

  Future<void> load(String tarih) async {
    state = state.copyWith(
      isLoading: true,
      seciliTarih: tarih,
      clearHata: true,
    );

    // Her yükleme sırasında hedefleri de güncelle (profil değişmiş olabilir).
    _hesaplaHedefler();

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
    if (onceki != null) {
      state = state.copyWith(veri: onceki.copyWith(suMl: onceki.suMl + ml));
    }
    try {
      await _api.suEkle(tarih: tarih, miktarMl: ml);
      await load(tarih);
    } catch (_) {
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          veri: onceki,
          hata: 'Su eklenemedi.',
        );
      }
    }
  }

  Future<List<BesinModel>> besinAra(String query) {
    return _api.besinAra(query);
  }

  Future<void> ogunEkle({
    required String ogunTipi,
    int? besinId,
    String? besinIsim,
    required double miktar,
    int kalori = 0,
    double protein = 0,
    double karbonhidrat = 0,
    double yag = 0,
  }) async {
    final tarih = state.seciliTarih;
    state = state.copyWith(isLoading: true, clearHata: true);
    try {
      await _api.ogunEkle(
        tarih: tarih,
        ogunTipi: ogunTipi,
        besinId: besinId,
        besinIsim: besinIsim,
        miktar: miktar,
        kalori: kalori,
        protein: protein,
        karbonhidrat: karbonhidrat,
        yag: yag,
      );
      await load(tarih);
    } catch (_) {
      if (mounted) {
        state = state.copyWith(isLoading: false, hata: 'Besin eklenemedi.');
      }
    }
  }

  Future<void> ogunSil(int id) async {
    final tarih = state.seciliTarih;
    state = state.copyWith(isLoading: true, clearHata: true);
    try {
      await _api.ogunSil(id);
      await load(tarih);
    } catch (_) {
      if (mounted) {
        state = state.copyWith(isLoading: false, hata: 'Kayıt silinemedi.');
      }
    }
  }

  static String _bugunStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

final nutritionProvider =
    StateNotifierProvider<NutritionNotifier, NutritionState>((ref) {
      return NutritionNotifier(ref);
    });
