import 'package:fitrehber_mobile/features/profil/profil_ekrani.dart';
import 'package:fitrehber_mobile/features/profil/providers/profil_provider.dart';
import 'package:fitrehber_mobile/shared/api_servisi.dart';
import 'package:fitrehber_mobile/shared/models/profil_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('profil ekranı getirilen profil verisini gösterir', (
    tester,
  ) async {
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
      startWeight: 85,
      goal: 'Fat loss',
      gender: 'B',
      isOnboarded: true,
      birthDate: null,
      joinDate: null,
      customWaterGoalMl: null,
      isStaff: true,
      isSuperuser: true,
      postCount: 8,
      achievements: [
        RozetModel(
          key: 'ilk_adim',
          name: 'Ilk Adim',
          icon: 'target',
          description: 'Ilk sorunu sor.',
          progress: 100,
          isUnlocked: true,
          metrics: [
            RozetMetrikModel(
              key: 'soru',
              label: 'Soru Sor',
              current: 1,
              target: 1,
              progress: 100,
            ),
          ],
        ),
      ],
      dailyActivity: GunlukAktiviteOzeti(
        averageMinutes: 12,
        days: [
          GunlukAktiviteGunu(
            isoDate: '2026-05-17',
            label: '17 May',
            day: 17,
            month: 'May',
            minutes: 32,
          ),
        ],
      ),
      recentActivities: [
        ProfilAktiviteModel(
          id: 1,
          tur: 'icerik',
          detay: 'Yeni gonderi olusturdun',
          tarih: DateTime(2026, 5, 17),
          icerikId: null,
          icerikBaslik: 'Protein rehberi',
          yorumId: null,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profilProvider.overrideWith(
            (ref) => _SahteProfilDenetleyici(profile),
          ),
        ],
        child: const MaterialApp(home: ProfilEkrani()),
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

class _SahteProfilDenetleyici extends ProfilDenetleyici {
  _SahteProfilDenetleyici(ProfilModel profile) : super(ApiServisi()) {
    state = const AsyncValue.loading();
    state = AsyncValue.data(profile);
  }
}
