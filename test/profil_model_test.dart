import 'package:fitrehber_mobile/shared/models/profil_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses flat and nested profile payload values', () {
    final profile = ProfilModel.fromJson({
      'id': '7',
      'user': {
        'username': 'baran',
        'email': 'baran@example.com',
        'first_name': 'Baran',
        'last_name': 'Fit',
        'date_joined': '2026-05-01T10:00:00Z',
        'is_staff': true,
        'is_superuser': true,
      },
      'hakkinda': 'Training consistently.',
      'foto': '/media/avatars/baran.png',
      'boy': '180',
      'kilo': '81.5',
      'hedef_kilo': '76',
      'fitness_hedefi': 'Fat loss',
      'cinsiyet': 'B',
      'is_onboarded': true,
      'dogum_tarihi': '1998-03-12',
      'post_count': 8,
      'rozetler': {
        'items': [
          {
            'key': 'ilk_adim',
            'name': 'Ilk Adim',
            'icon': 'target',
            'description': 'Ilk sorunu sor.',
            'progress': 100,
            'is_unlocked': true,
            'metrics': [
              {'key': 'soru', 'label': 'Soru Sor', 'current': 1, 'target': 1},
            ],
          },
        ],
      },
      'gunluk_aktivite': {
        'average_minutes': 12,
        'days': [
          {
            'iso_date': '2026-05-17',
            'date': '17 May',
            'day': 17,
            'month': 'May',
            'minutes': 32,
          },
        ],
      },
      'son_aktiviteler': [
        {
          'id': 4,
          'type': 'icerik',
          'detail': 'Yeni gonderi olusturdun',
          'date': '2026-05-17T10:00:00Z',
          'content_id': 9,
          'content_title': 'Protein rehberi',
        },
      ],
    });

    expect(profile.id, 7);
    expect(profile.displayName, 'Baran Fit');
    expect(profile.email, 'baran@example.com');
    expect(
      profile.avatarUrl,
      'https://fitrehber.com.tr/media/avatars/baran.png',
    );
    expect(profile.height, 180);
    expect(profile.weight, 81.5);
    expect(profile.targetWeight, 76);
    expect(profile.goal, 'Fat loss');
    expect(profile.gender, 'B');
    expect(profile.isOnboarded, isTrue);
    expect(profile.birthDate, DateTime(1998, 3, 12));
    expect(profile.joinDate, DateTime.parse('2026-05-01T10:00:00Z'));
    expect(profile.isAdmin, isTrue);
    expect(profile.isSuperuser, isTrue);
    expect(profile.isStaff, isTrue);
    expect(profile.postCount, 8);
    expect(profile.bmi, closeTo(25.15, 0.01));
    expect(profile.roleName, 'Admin');
    expect(profile.achievements, hasLength(1));
    expect(profile.achievements.first.isUnlocked, isTrue);
    expect(profile.achievements.first.metrics.first.progress, 100);
    expect(profile.dailyActivity.averageMinutes, 12);
    expect(profile.dailyActivity.days.first.minutes, 32);
    expect(profile.recentActivities.first.contentId, 9);
  });

  test('parses deployed profile api payload', () {
    final profile = ProfilModel.fromJson({
      'id': 3,
      'user': {
        'id': 3,
        'username': 'Nyancat',
        'first_name': '',
        'last_name': '',
        'is_staff': true,
        'is_superuser': true,
      },
      'hakkinda': 'Merhaba, ben spor tutkunuyum!',
      'is_banned': 0,
      'foto': 'profil_fotograflari/avatar.webp',
      'post_count': 8,
      'date_joined': '2026-02-21T10:00:00Z',
    });

    expect(profile.id, 3);
    expect(profile.username, 'Nyancat');
    expect(
      profile.avatarUrl,
      'https://fitrehber.com.tr/media/profil_fotograflari/avatar.webp',
    );
    expect(profile.bio, 'Merhaba, ben spor tutkunuyum!');
    expect(profile.isAdmin, isTrue);
    expect(profile.postCount, 8);
    expect(profile.roleName, 'Admin');
    expect(profile.gender, 'B');
    expect(profile.isOnboarded, isFalse);
  });

  test('prefers nested user id over profile row id', () {
    final profile = ProfilModel.fromJson({
      'id': 99,
      'user': {'id': 7, 'username': 'mobile-user'},
      'is_onboarded': false,
    });

    expect(profile.id, 7);
    expect(profile.username, 'mobile-user');
  });

  test('empty profile can preserve authenticated user identity', () {
    final profile = ProfilModel.empty(
      id: 12,
      username: 'new-user',
      email: 'new@example.com',
    );

    expect(profile.id, 12);
    expect(profile.username, 'new-user');
    expect(profile.email, 'new@example.com');
    expect(profile.isOnboarded, isFalse);
  });
}
