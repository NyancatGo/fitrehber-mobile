import 'package:flutter/foundation.dart';
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
    // Profil değişikliklerini dinle (su hedefi, kilo, boy, hedef vs.).
    // Profile güncellenince hedefler anında recompute.
    _ref.listen<SessionState>(sessionControllerProvider, (prev, next) {
      final p = prev?.profile;
      final n = next.profile;
      final degisti = p?.customWaterGoalMl != n?.customWaterGoalMl ||
          p?.weight != n?.weight ||
          p?.height != n?.height ||
          p?.goal != n?.goal ||
          p?.gender != n?.gender ||
          p?.birthDate != n?.birthDate;
      if (degisti) _hesaplaHedefler();
    });
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
      debugPrint('[NutritionNotifier.load] $e');
      // Veri yoksa UI'ı boş modelle ayakta tut, ama hatayı kullanıcıya göster.
      state = state.copyWith(
        isLoading: false,
        veri: GunlukBeslenmeModel(tarih: tarih),
        hata: _mesaj(e),
      );
    }
  }

  Future<bool> suEkle(int ml) async {
    final onceki = state.veri;
    final tarih = state.seciliTarih;
    if (onceki != null) {
      // Optimistic update — kullanici barini hemen gorur. API yaniti
      // kanonik degeri overwrite eder (race veya clamp farkliysa duzelir).
      final yeni = (onceki.suMl + ml).clamp(0, 100000);
      state = state.copyWith(veri: onceki.copyWith(suMl: yeni));
    }
    try {
      // API yaniti guncel GunlukBeslenmeSu modelini doner — onu kullaniyoruz.
      // Eski 'await load(tarih)' redundant GET'i kaldirildi: hem bir HTTP
      // round-trip tasarrufu, hem hedefler recompute'u atlanir (su ekleme
      // profili degistirmez).
      final guncel = await _api.suEkle(tarih: tarih, miktarMl: ml);
      if (mounted) {
        state = state.copyWith(veri: guncel);
      }
      return true;
    } catch (e) {
      debugPrint('[NutritionNotifier.suEkle] $e');
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          veri: onceki,
          hata: _mesaj(e),
        );
      }
      return false;
    }
  }

  Future<List<BesinModel>> besinAra(String query) {
    return _api.besinAra(query);
  }

  Future<bool> ogunEkle({
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
      return true;
    } catch (e) {
      debugPrint('[NutritionNotifier.ogunEkle] $e');
      if (mounted) {
        state = state.copyWith(isLoading: false, hata: _mesaj(e));
      }
      return false;
    }
  }

  /// Mevcut kaydı yeni gramajla günceller — TEK atomic PATCH isteği.
  ///
  /// Eski 'önce yeni ekle, sonra eskiyi sil' workflow'u (non-atomic) artık
  /// kullanilmiyor: network kesilirse duplicate kayit kaliyordu. API'deki
  /// yeni `OgunGuncelle` endpoint'i transaction.atomic() icinde:
  ///   - Dogrulanmis besin ise makrolari yeniden hesaplar (server-side)
  ///   - Custom food ise istemci payload'unu kullanir
  ///   - _gunluk_toplami_guncelle ile gunluk agreganini lock altinda
  ///     yeniler.
  ///
  /// Mobil sadece miktar gonderir; makro recompute sunucuda olur. Custom
  /// food icin geri uyumluluk: sunucu olcekleme yapiyor, ama mobil
  /// agresif hassasiyet istiyorsa makrolari da yollayabilir.
  Future<bool> ogunGuncelle({
    required OgunKaydiModel eski,
    required double yeniMiktar,
  }) async {
    if (yeniMiktar <= 0) {
      state = state.copyWith(hata: 'Miktar sıfırdan büyük olmalı.');
      return false;
    }
    if (yeniMiktar == eski.miktar) return true; // Değişiklik yok.

    final tarih = state.seciliTarih;
    state = state.copyWith(isLoading: true, clearHata: true);

    try {
      await _api.ogunGuncelle(id: eski.id, miktar: yeniMiktar);
      // Toplam agregayi tazelemek icin gunluk modeli tekrar cek.
      await load(tarih);
      return true;
    } catch (e) {
      debugPrint('[ogunGuncelle] PATCH başarısız: $e');
      if (mounted) {
        state = state.copyWith(isLoading: false, hata: _mesaj(e));
      }
      return false;
    }
  }

  Future<bool> ogunSil(int id) async {
    final tarih = state.seciliTarih;
    state = state.copyWith(isLoading: true, clearHata: true);
    try {
      await _api.ogunSil(id);
      await load(tarih);
      return true;
    } catch (e) {
      debugPrint('[NutritionNotifier.ogunSil] $e');
      if (mounted) {
        state = state.copyWith(isLoading: false, hata: _mesaj(e));
      }
      return false;
    }
  }

  String _mesaj(Object e) {
    // ApiService genelde anlaşılır bir String fırlatır; ama
    // ağ/timeout gibi durumlarda Exception/DioException gelebilir.
    final raw = e is String ? e : e.toString();
    return raw.replaceFirst(RegExp(r'^Exception: '), '');
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
