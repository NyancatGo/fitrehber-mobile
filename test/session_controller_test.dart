// SessionController._loadProfile davranisi:
//   - HTTP auth hatasi (string/Exception) -> oturum sonlandirilmali (logout)
//   - DioException network hatasi -> oturum KORUNMALI, profile cached/empty
//
// Antigravity Faz 2 #5 regresyon testi: offline iken uygulama acilirken
// kullanici zorla cikisa atilmamali.

import 'package:dio/dio.dart';
import 'package:fitrehber_mobile/shared/api_service.dart';
import 'package:fitrehber_mobile/shared/auth_service.dart';
import 'package:fitrehber_mobile/shared/models/profil_model.dart';
import 'package:fitrehber_mobile/shared/session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApiService extends ApiService {
  _FakeApiService(this._error);
  final Object _error;

  @override
  Future<ProfilModel> getProfil() async => throw _error;
}

class _CountingAuthService extends AuthService {
  int logoutCalls = 0;

  @override
  Future<String?> getAccessToken() async => 'fake-token';

  @override
  Future<void> logout() async {
    logoutCalls += 1;
  }
}

void main() {
  test(
    'restore() preserves session on DioException (offline) — no logout',
    () async {
      final dioErr = DioException(
        requestOptions: RequestOptions(path: '/api/profil/'),
        type: DioExceptionType.connectionError,
        message: 'Connection failed',
      );
      final auth = _CountingAuthService();
      final api = _FakeApiService(dioErr);
      final controller = SessionController(
        authService: auth,
        apiService: api,
      );

      await controller.restore();

      // Logout cagrilmamali; state oturum acik kalmali.
      expect(auth.logoutCalls, 0);
      expect(controller.state.isLoggedIn, true);
      // Profile cache yoktu, empty profile fallback kullanildi.
      expect(controller.state.profile, isNotNull);
      // Error mesaji set edilmis olmali (kullaniciyi bilgilendirmek icin).
      expect(controller.state.error, isNotNull);
    },
  );

  test(
    'restore() logs out on real auth error (non-DioException)',
    () async {
      // ApiService gercek 401 durumunda String firlatir.
      const authErr = 'Oturum süren doldu.';
      final auth = _CountingAuthService();
      final api = _FakeApiService(authErr);
      final controller = SessionController(
        authService: auth,
        apiService: api,
      );

      await controller.restore();

      // Auth hatasi -> logout cagrilmali.
      expect(auth.logoutCalls, 1);
      expect(controller.state.isLoggedIn, false);
    },
  );
}
