import 'package:fitrehber_mobile/core/router/app_router.dart';
import 'package:fitrehber_mobile/features/auth/email_verification_screen.dart';
import 'package:fitrehber_mobile/features/auth/forgot_password_screen.dart';
import 'package:fitrehber_mobile/shared/api_service.dart';
import 'package:fitrehber_mobile/shared/auth_service.dart';
import 'package:fitrehber_mobile/shared/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _LoggedOutSessionController extends SessionController {
  _LoggedOutSessionController()
    : super(authService: AuthService(), apiService: ApiService()) {
    state = const SessionState(isLoading: false);
  }

  @override
  Future<void> restore() async {}
}

Future<void> _pumpRoute(WidgetTester tester, String location) async {
  final container = ProviderContainer(
    overrides: [
      sessionControllerProvider.overrideWith(
        (ref) => _LoggedOutSessionController(),
      ),
    ],
  );
  addTearDown(container.dispose);

  final router = container.read(appRouterProvider);
  addTearDown(router.dispose);
  router.go(location);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('email verification route is available while logged out', (
    tester,
  ) async {
    await _pumpRoute(tester, '/email-dogrulama?email=test@example.com');

    expect(find.byType(EmailVerificationScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('forgot password route is available while logged out', (
    tester,
  ) async {
    await _pumpRoute(tester, '/sifremi-unuttum');

    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
  });
}
