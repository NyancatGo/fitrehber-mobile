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
  final String goal;
  final DateTime? birthDate;
  final DateTime? joinDate;
  final bool isStaff;
  final bool isSuperuser;
  final int postCount;

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
    required this.goal,
    required this.birthDate,
    required this.joinDate,
    required this.isStaff,
    required this.isSuperuser,
    required this.postCount,
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

    return ProfilModel(
      id: _asInt(read(['id', 'user_id'])) ?? 0,
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
      goal: _asString(read(['fitness_hedefi', 'goal', 'hedef'])),
      birthDate: _asDate(read(['dogum_tarihi', 'birth_date', 'birthDate'])),
      joinDate: _asDate(
        read(['date_joined', 'join_date', 'joinDate', 'joined_at']),
      ),
      isStaff: _asBool(read(['is_staff', 'isStaff'])),
      isSuperuser: _asBool(read(['is_superuser', 'isSuperuser'])),
      postCount: _asInt(read(['post_count', 'postCount'])) ?? 0,
    );
  }

  factory ProfilModel.empty({String? username}) {
    return ProfilModel(
      id: 0,
      username: username ?? '',
      email: '',
      firstName: '',
      lastName: '',
      avatarUrl: null,
      bio: '',
      height: null,
      weight: null,
      targetWeight: null,
      goal: '',
      birthDate: null,
      joinDate: null,
      isStaff: false,
      isSuperuser: false,
      postCount: 0,
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
    String? goal,
    DateTime? birthDate,
    DateTime? joinDate,
    bool? isStaff,
    bool? isSuperuser,
    int? postCount,
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
      goal: goal ?? this.goal,
      birthDate: birthDate ?? this.birthDate,
      joinDate: joinDate ?? this.joinDate,
      isStaff: isStaff ?? this.isStaff,
      isSuperuser: isSuperuser ?? this.isSuperuser,
      postCount: postCount ?? this.postCount,
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

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

String _asString(Object? value) => value?.toString().trim() ?? '';

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
  return normalized == 'true' ||
      normalized == '1' ||
      normalized == 'yes';
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
