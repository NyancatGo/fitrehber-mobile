import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_service.dart';
import 'auth_service.dart';
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
    final token = await _authService.getAccessToken();
    if (token == null || token.isEmpty) {
      state = const SessionState(isLoading: false);
      return;
    }

    await _loadProfile();
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

  Future<void> register(String username, String password, String email) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _authService.register(username, password, email);
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
      if (logoutOnFailure) {
        await _authService.logout();
        state = SessionState(isLoading: false, error: error.toString());
      } else {
        state = SessionState(
          isLoading: false,
          isLoggedIn: true,
          profile: state.profile ?? ProfilModel.empty(),
          error: error.toString(),
        );
      }
    }
  }
}
