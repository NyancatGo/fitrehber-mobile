import 'package:fitrehber_mobile/features/profile/profile_screen.dart';
import 'package:fitrehber_mobile/features/profile/providers/profile_provider.dart';
import 'package:fitrehber_mobile/shared/api_service.dart';
import 'package:fitrehber_mobile/shared/models/profil_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('profile screen renders fetched profile data', (tester) async {
    final profile = ProfilModel(
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
      gender: 'B',
      isOnboarded: true,
      birthDate: null,
      joinDate: null,
      isStaff: true,
      isSuperuser: true,
      postCount: 8,
      achievements: [
        AchievementModel(
          key: 'ilk_adim',
          name: 'Ilk Adim',
          icon: 'target',
          description: 'Ilk sorunu sor.',
          progress: 100,
          isUnlocked: true,
          metrics: [
            AchievementMetricModel(
              key: 'soru',
              label: 'Soru Sor',
              current: 1,
              target: 1,
              progress: 100,
            ),
          ],
        ),
      ],
      dailyActivity: DailyActivitySummary(
        averageMinutes: 12,
        days: [
          DailyActivityDay(
            isoDate: '2026-05-17',
            label: '17 May',
            day: 17,
            month: 'May',
            minutes: 32,
          ),
        ],
      ),
      recentActivities: [
        ProfileActivityModel(
          id: 1,
          type: 'icerik',
          detail: 'Yeni gonderi olusturdun',
          date: DateTime(2026, 5, 17),
          contentId: null,
          contentTitle: 'Protein rehberi',
          commentId: null,
        ),
      ],
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

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('Fat loss'), findsOneWidget);
    expect(find.text('Başarılar'), findsOneWidget);
    expect(find.text('Aktivite Haritası'), findsOneWidget);
    expect(find.text('Son Aktiviteler'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1400));
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
