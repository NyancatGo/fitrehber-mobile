import 'package:fitrehber_mobile/features/profile/profile_screen.dart';
import 'package:fitrehber_mobile/features/profile/providers/profile_provider.dart';
import 'package:fitrehber_mobile/shared/api_service.dart';
import 'package:fitrehber_mobile/shared/models/profil_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('profile screen renders fetched profile data', (tester) async {
    const profile = ProfilModel(
      id: 7,
      username: 'baran',
      email: 'baran@example.com',
      firstName: 'Baran',
      lastName: 'Fit',
      avatarUrl: null,
      bio: 'Training consistently.',
      height: 180,
      weight: 81,
      targetWeight: 76,
      goal: 'Fat loss',
      birthDate: null,
      joinDate: null,
      isStaff: true,
      isSuperuser: true,
      postCount: 8,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith((ref) => _FakeProfileNotifier(profile)),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );

    expect(find.text('Baran Fit'), findsOneWidget);
    expect(find.text('@baran'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('180 cm'), findsOneWidget);
    expect(find.text('81 kg'), findsOneWidget);
    expect(find.text('Fat loss'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('baran@example.com'), findsOneWidget);
  });
}

class _FakeProfileNotifier extends ProfileNotifier {
  _FakeProfileNotifier(ProfilModel profile) : super(ApiService()) {
    state = const AsyncValue.loading();
    state = AsyncValue.data(profile);
  }
}
