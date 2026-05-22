import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_service.dart';
import 'auth_service.dart';
import 'google_oauth_flow.dart';
import 'models/profil_model.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

final sessionControllerProvider =
    StateNotifierProvider<SessionController, SessionState>((ref) {
      final controller = SessionController(
        authService: ref.watch(authServiceProvider),
        apiService: ref.watch(apiServiceProvider),
      );
      controller.restore();
      return controller;
    });

class SessionState {
  final bool isLoading;
  final bool isLoggedIn;
  final ProfilModel? profile;
  final String? error;

  const SessionState({
    this.isLoading = true,
    this.isLoggedIn = false,
    this.profile,
    this.error,
  });

  bool get isOnboarded => profile?.isOnboarded ?? false;

  SessionState copyWith({
    bool? isLoading,
    bool? isLoggedIn,
    ProfilModel? profile,
    bool clearProfile = false,
    String? error,
    bool clearError = false,
  }) {
    return SessionState(
      isLoading: isLoading ?? this.isLoading,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      profile: clearProfile ? null : (profile ?? this.profile),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SessionController extends StateNotifier<SessionState> {
  final AuthService _authService;
  final ApiService _apiService;

  SessionController({
    required AuthService authService,
    required ApiService apiService,
  }) : _authService = authService,
       _apiService = apiService,
       super(const SessionState());

  Future<void> restore() async {
    // Web Google OAuth: tarayıcı Google'dan dönüp uygulamayı yeniden
    // yüklediğinde URL'de code+state olur. Bunu burada işliyoruz.
    if (kIsWeb && await _tryConsumeWebGoogleCallback()) {
      return;
    }

    final token = await _authService.getAccessToken();
    if (token == null || token.isEmpty) {
      state = const SessionState(isLoading: false);
      return;
    }

    await _loadProfile();
  }

  /// Web akışında Google OAuth dönüşünü işler.
  ///
  /// URL'de `code`+`state` ve depoda bekleyen (state, code_verifier) varsa
  /// token exchange yapar. İşlendiğinde (başarılı ya da hatayla) `true`,
  /// işlenecek bir callback yoksa `false` döner — `false` durumunda normal
  /// token tabanlı oturum geri yüklemesi devam eder.
  Future<bool> _tryConsumeWebGoogleCallback() async {
    final callback = GoogleOAuthFlow.webCallbackFromUri(Uri.base);
    if (callback == null) return false;

    final pending = await _authService.readGooglePending();
    if (pending == null) {
      // Bekleyen istek yok (ör. sayfa yenilendi, kod zaten tüketildi).
      return false;
    }

    // Tek kullanımlık: sayfa yeniden yüklenirse aynı kod tekrar denenmesin.
    await _authService.clearGooglePending();

    // CSRF koruması: dönen state, başlatılan state ile birebir eşleşmeli.
    if (pending.state != callback.state) {
      return false;
    }

    try {
      await _authService.exchangeGoogleCode(
        code: callback.code,
        state: callback.state,
        codeVerifier: pending.codeVerifier,
      );
      await _loadProfile(logoutOnFailure: false);
    } catch (error) {
      state = SessionState(isLoading: false, error: error.toString());
    }
    return true;
  }

  Future<void> login(String username, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _authService.login(username, password);
      await _loadProfile(logoutOnFailure: false);
    } catch (error) {
      state = SessionState(isLoading: false, error: error.toString());
      rethrow;
    }
  }

  Future<void> register(
    String username,
    String password,
    String email,
    String password2,
  ) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _authService.register(username, password, email, password2);
      await _authService.logout();
      state = const SessionState(isLoading: false);
    } catch (error) {
      state = SessionState(isLoading: false, error: error.toString());
      rethrow;
    }
  }

  Future<void> loginWithGoogleCode({
    required String code,
    required String stateToken,
    required String codeVerifier,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _authService.exchangeGoogleCode(
        code: code,
        state: stateToken,
        codeVerifier: codeVerifier,
      );
      await _loadProfile(logoutOnFailure: false);
    } catch (error) {
      state = SessionState(isLoading: false, error: error.toString());
      rethrow;
    }
  }

  Future<void> completeOnboarding(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final profile = await _apiService.completeOnboarding(data);
      state = SessionState(
        isLoading: false,
        isLoggedIn: true,
        profile: profile,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
      rethrow;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    state = const SessionState(isLoading: false);
  }

  Future<void> refreshProfile() => _loadProfile(logoutOnFailure: false);

  Future<void> _loadProfile({bool logoutOnFailure = true}) async {
    try {
      final profile = await _apiService.getProfil();
      state = SessionState(
        isLoading: false,
        isLoggedIn: true,
        profile: profile,
      );
    } catch (error) {
      // ApiService validateStatus = (_) => true; yani HTTP 401/403 gibi
      // gercek auth hatalari DioException olarak DEGIL, _hataAyikla'dan
      // dogan String/Exception olarak gelir. DioException ise yalniz ag
      // kesintilerinde (timeout, connection error, DNS) firlatilir.
      //
      // Internet yokken kullaniciyi logout edip token'lari silmek hatali UX
      // (metro/tunel vb. ortamlarda surekli zorla cikis). Bu yuzden:
      //  - DioException (network) -> oturumu KORU, cached profili goster.
      //  - Diger hatalar (auth) -> logoutOnFailure parametresi karar verir.
      final isNetworkError = error is DioException;
      if (isNetworkError || !logoutOnFailure) {
        state = SessionState(
          isLoading: false,
          isLoggedIn: true,
          profile: state.profile ?? ProfilModel.empty(),
          error: error.toString(),
        );
        return;
      }
      await _authService.logout();
      state = SessionState(isLoading: false, error: error.toString());
    }
  }
}
