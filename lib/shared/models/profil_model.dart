const _siteBaseUrl = 'https://fitrehber.com.tr';
const _mediaBaseUrl = '$_siteBaseUrl/media/';

class ProfilModel {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final String bio;
  final double? height;
  final double? weight;
  final double? targetWeight;
  /// Hedef belirlendiği veya değiştirildiği andaki kilo — ilerleme barının
  /// %0 referans noktası. Backend `baslangic_kilo` alanından gelir.
  final double? startWeight;
  final String goal;
  final String gender;
  final bool isOnboarded;
  final DateTime? birthDate;
  final DateTime? joinDate;
  /// Kullanıcının belirlediği günlük su hedefi (ml). NULL/0 ise
  /// `NutritionCalculator` kilo×35 ml formülünü kullanır.
  final int? customWaterGoalMl;
  final bool isStaff;
  final bool isSuperuser;
  final int postCount;
  final List<AchievementModel> achievements;
  final DailyActivitySummary dailyActivity;
  final List<ProfileActivityModel> recentActivities;

  const ProfilModel({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.avatarUrl,
    required this.bio,
    required this.height,
    required this.weight,
    required this.targetWeight,
    required this.startWeight,
    required this.goal,
    required this.gender,
    required this.isOnboarded,
    required this.birthDate,
    required this.joinDate,
    required this.customWaterGoalMl,
    required this.isStaff,
    required this.isSuperuser,
    required this.postCount,
    this.achievements = const [],
    this.dailyActivity = const DailyActivitySummary(),
    this.recentActivities = const [],
  });

  factory ProfilModel.fromJson(Map<String, dynamic> json) {
    final user = _asMap(json['user'] ?? json['kullanici']);
    final profile = _asMap(json['profile'] ?? json['profil']);

    Object? read(List<String> keys) {
      for (final key in keys) {
        if (json.containsKey(key)) return json[key];
        if (profile.containsKey(key)) return profile[key];
        if (user.containsKey(key)) return user[key];
      }
      return null;
    }

    final achievementsPayload = read(['rozetler', 'achievements']);
    final dailyActivityPayload = read([
      'gunluk_aktivite',
      'daily_activity',
      'dailyActivity',
    ]);
    final recentActivitiesPayload = read([
      'son_aktiviteler',
      'recent_activities',
      'recentActivities',
    ]);

    return ProfilModel(
      id: _asInt(user['id'] ?? read(['user_id', 'id'])) ?? 0,
      username: _asString(read(['username', 'kullanici_adi'])),
      email: _asString(read(['email', 'e_posta'])),
      firstName: _asString(read(['first_name', 'firstName', 'ad'])),
      lastName: _asString(read(['last_name', 'lastName', 'soyad'])),
      avatarUrl: _normalizeMediaUrl(
        read([
          'foto_url',
          'avatar_url',
          'avatarUrl',
          'avatar',
          'foto',
          'profile_picture',
          'profil_resmi',
        ]),
      ),
      bio: _asString(read(['bio', 'hakkinda', 'about'])),
      height: _asDouble(read(['boy', 'height'])),
      weight: _asDouble(read(['kilo', 'weight'])),
      targetWeight: _asDouble(
        read(['hedef_kilo', 'target_weight', 'targetWeight']),
      ),
      startWeight: _asDouble(
        read(['baslangic_kilo', 'start_weight', 'startWeight']),
      ),
      goal: _asString(read(['fitness_hedefi', 'goal', 'hedef'])),
      gender: _asString(read(['cinsiyet', 'gender'])).isEmpty
          ? 'B'
          : _asString(read(['cinsiyet', 'gender'])),
      isOnboarded: _asBool(read(['is_onboarded', 'isOnboarded'])),
      birthDate: _asDate(read(['dogum_tarihi', 'birth_date', 'birthDate'])),
      joinDate: _asDate(
        read(['date_joined', 'join_date', 'joinDate', 'joined_at']),
      ),
      customWaterGoalMl: _asInt(read([
        'gunluk_su_hedefi_ml',
        'daily_water_goal_ml',
        'customWaterGoalMl',
      ])),
      isStaff: _asBool(read(['is_staff', 'isStaff'])),
      isSuperuser: _asBool(read(['is_superuser', 'isSuperuser'])),
      postCount: _asInt(read(['post_count', 'postCount'])) ?? 0,
      achievements: _parseAchievements(achievementsPayload),
      dailyActivity: DailyActivitySummary.fromJson(dailyActivityPayload),
      recentActivities: _asList(
        recentActivitiesPayload,
      ).map(ProfileActivityModel.fromJson).toList(),
    );
  }

  factory ProfilModel.empty({
    int id = 0,
    String? username,
    String email = '',
    String firstName = '',
    String lastName = '',
  }) {
    return ProfilModel(
      id: id,
      username: username ?? '',
      email: email,
      firstName: firstName,
      lastName: lastName,
      avatarUrl: null,
      bio: '',
      height: null,
      weight: null,
      targetWeight: null,
      startWeight: null,
      goal: '',
      gender: 'B',
      isOnboarded: false,
      birthDate: null,
      joinDate: null,
      customWaterGoalMl: null,
      isStaff: false,
      isSuperuser: false,
      postCount: 0,
      achievements: const [],
      dailyActivity: const DailyActivitySummary(),
      recentActivities: const [],
    );
  }

  ProfilModel copyWith({
    int? id,
    String? username,
    String? email,
    String? firstName,
    String? lastName,
    String? avatarUrl,
    String? bio,
    double? height,
    double? weight,
    double? targetWeight,
    double? startWeight,
    String? goal,
    String? gender,
    bool? isOnboarded,
    DateTime? birthDate,
    DateTime? joinDate,
    int? customWaterGoalMl,
    bool? isStaff,
    bool? isSuperuser,
    int? postCount,
    List<AchievementModel>? achievements,
    DailyActivitySummary? dailyActivity,
    List<ProfileActivityModel>? recentActivities,
  }) {
    return ProfilModel(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      targetWeight: targetWeight ?? this.targetWeight,
      startWeight: startWeight ?? this.startWeight,
      goal: goal ?? this.goal,
      gender: gender ?? this.gender,
      isOnboarded: isOnboarded ?? this.isOnboarded,
      birthDate: birthDate ?? this.birthDate,
      joinDate: joinDate ?? this.joinDate,
      customWaterGoalMl: customWaterGoalMl ?? this.customWaterGoalMl,
      isStaff: isStaff ?? this.isStaff,
      isSuperuser: isSuperuser ?? this.isSuperuser,
      postCount: postCount ?? this.postCount,
      achievements: achievements ?? this.achievements,
      dailyActivity: dailyActivity ?? this.dailyActivity,
      recentActivities: recentActivities ?? this.recentActivities,
    );
  }

  /// Kullanıcının rolünü belirler (Admin > Staff > Standart).
  bool get isAdmin => isSuperuser;

  String get roleName {
    if (isSuperuser) return 'Admin';
    if (isStaff) return 'Yetkili';
    return 'Standart Üye';
  }

  String get displayName {
    final fullName = '$firstName $lastName'.trim();
    if (fullName.isNotEmpty) return fullName;
    if (username.isNotEmpty) return username;
    return 'FitRehber Üyesi';
  }

  String get initials {
    final parts = displayName
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'FR';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  double? get bmi {
    final heightValue = height;
    final weightValue = weight;
    if (heightValue == null || weightValue == null || heightValue <= 0) {
      return null;
    }

    final meters = heightValue / 100;
    return weightValue / (meters * meters);
  }

  String get bmiCategory {
    final value = bmi;
    if (value == null) return 'Eksik veri';
    if (value < 18.5) return 'Düşük';
    if (value < 25) return 'Dengeli';
    if (value < 30) return 'Yüksek';
    return 'Çok yüksek';
  }
}

class AchievementModel {
  final String key;
  final String name;
  final String icon;
  final String description;
  final int progress;
  final bool isUnlocked;
  final List<AchievementMetricModel> metrics;

  const AchievementModel({
    required this.key,
    required this.name,
    required this.icon,
    required this.description,
    required this.progress,
    required this.isUnlocked,
    required this.metrics,
  });

  factory AchievementModel.fromJson(Object? value) {
    final json = _asMap(value);
    final progress = ((_asInt(json['progress']) ?? 0).clamp(0, 100)).toInt();

    return AchievementModel(
      key: _asString(json['key']),
      name: _asString(json['name']),
      icon: _asString(json['icon']),
      description: _asString(json['description']),
      progress: progress,
      isUnlocked:
          _asBool(json['is_unlocked'] ?? json['isUnlocked']) || progress >= 100,
      metrics: _asList(
        json['metrics'],
      ).map(AchievementMetricModel.fromJson).toList(),
    );
  }
}

class AchievementMetricModel {
  final String key;
  final String label;
  final int current;
  final int target;
  final int progress;

  const AchievementMetricModel({
    required this.key,
    required this.label,
    required this.current,
    required this.target,
    required this.progress,
  });

  factory AchievementMetricModel.fromJson(Object? value) {
    final json = _asMap(value);
    final current = _asInt(json['current']) ?? 0;
    final target = _asInt(json['target']) ?? 0;
    final computedProgress = target <= 0
        ? 0
        : (((current / target) * 100).floor().clamp(0, 100)).toInt();

    return AchievementMetricModel(
      key: _asString(json['key']),
      label: _asString(json['label']),
      current: current,
      target: target,
      progress: ((_asInt(json['progress']) ?? computedProgress).clamp(
        0,
        100,
      )).toInt(),
    );
  }
}

class DailyActivitySummary {
  final int averageMinutes;
  final List<DailyActivityDay> days;

  const DailyActivitySummary({this.averageMinutes = 0, this.days = const []});

  factory DailyActivitySummary.fromJson(Object? value) {
    final json = _asMap(value);

    return DailyActivitySummary(
      averageMinutes:
          _asInt(
            json['average_minutes'] ??
                json['averageMinutes'] ??
                json['gunluk_ortalama'],
          ) ??
          0,
      days: _asList(
        json['days'] ?? json['gunler'] ?? json['veriler'],
      ).map(DailyActivityDay.fromJson).toList(),
    );
  }
}

class DailyActivityDay {
  final String isoDate;
  final String label;
  final int day;
  final String month;
  final int minutes;

  const DailyActivityDay({
    required this.isoDate,
    required this.label,
    required this.day,
    required this.month,
    required this.minutes,
  });

  factory DailyActivityDay.fromJson(Object? value) {
    final json = _asMap(value);

    return DailyActivityDay(
      isoDate: _asString(json['iso_date'] ?? json['isoDate']),
      label: _asString(json['date'] ?? json['tarih']),
      day: _asInt(json['day'] ?? json['gun']) ?? 0,
      month: _asString(json['month'] ?? json['ay']),
      minutes: _asInt(json['minutes'] ?? json['sure'] ?? json['sure_dk']) ?? 0,
    );
  }
}

class ProfileActivityModel {
  final int id;
  final String type;
  final String detail;
  final DateTime? date;
  final int? contentId;
  final String? contentTitle;
  final int? commentId;

  const ProfileActivityModel({
    required this.id,
    required this.type,
    required this.detail,
    required this.date,
    required this.contentId,
    required this.contentTitle,
    required this.commentId,
  });

  factory ProfileActivityModel.fromJson(Object? value) {
    final json = _asMap(value);

    return ProfileActivityModel(
      id: _asInt(json['id']) ?? 0,
      type: _asString(json['type'] ?? json['tur']),
      detail: _asString(json['detail'] ?? json['detay']),
      date: _asDate(json['date'] ?? json['tarih']),
      contentId: _asInt(json['content_id'] ?? json['contentId']),
      contentTitle: _asNullableString(
        json['content_title'] ?? json['contentTitle'],
      ),
      commentId: _asInt(json['comment_id'] ?? json['commentId']),
    );
  }
}

List<AchievementModel> _parseAchievements(Object? value) {
  final map = _asMap(value);
  final rawItems = map.isEmpty ? value : map['items'];
  return _asList(rawItems).map(AchievementModel.fromJson).toList();
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

String _asString(Object? value) => value?.toString().trim() ?? '';

String? _asNullableString(Object? value) {
  final parsed = _asString(value);
  return parsed.isEmpty ? null : parsed;
}

List<Object?> _asList(Object? value) {
  if (value is List<Object?>) return value;
  if (value is List) return value.cast<Object?>();
  return const [];
}

int? _asInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double? _asDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();

  final normalized = value.toString().trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

DateTime? _asDate(Object? value) {
  final raw = _asString(value);
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

bool _asBool(Object? value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;

  final normalized = value.toString().trim().toLowerCase();
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}

String? _normalizeMediaUrl(Object? value) {
  final raw = _asString(value);
  if (raw.isEmpty) return null;

  final uri = Uri.tryParse(raw);
  if (uri != null && uri.hasScheme) return raw;
  if (raw.startsWith('//')) return 'https:$raw';
  if (raw.startsWith('/media/')) return '$_siteBaseUrl$raw';
  if (raw.startsWith('media/')) return '$_siteBaseUrl/$raw';

  return '$_mediaBaseUrl${raw.replaceFirst(RegExp(r'^/+'), '')}';
}
