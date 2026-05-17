// Profil ekranı: biçimlendirme ve eşleme yardımcı fonksiyonları.
part of '../profile_screen.dart';

IconData _achievementIcon(String icon) {
  switch (icon) {
    case 'target':
      return Icons.ads_click;
    case 'star':
      return Icons.star_rounded;
    case 'heart':
      return Icons.favorite_rounded;
    case 'chat':
      return Icons.chat_bubble_rounded;
    case 'flame':
      return Icons.local_fire_department_rounded;
    case 'crown':
      return Icons.workspace_premium_rounded;
    default:
      return Icons.emoji_events_rounded;
  }
}

Color _activityLevelColor(int minutes) {
  if (minutes <= 0) return Colors.white.withValues(alpha: 0.08);
  if (minutes <= 20) return const Color(0xFF1E3A5F);
  if (minutes <= 45) return const Color(0xFF2563EB);
  if (minutes <= 90) return const Color(0xFF22D3EE);
  return const Color(0xFF34D399);
}

IconData _activityTypeIcon(String type) {
  switch (type) {
    case 'icerik':
      return Icons.add_circle_rounded;
    case 'yorum':
      return Icons.chat_rounded;
    case 'begeni':
      return Icons.favorite_rounded;
    case 'kayit':
      return Icons.bookmark_rounded;
    case 'rozet':
      return Icons.emoji_events_rounded;
    default:
      return Icons.bolt_rounded;
  }
}

Color _activityTypeColor(String type) {
  switch (type) {
    case 'icerik':
      return const Color(0xFF60A5FA);
    case 'yorum':
      return const Color(0xFF34D399);
    case 'begeni':
      return const Color(0xFFEF4444);
    case 'kayit':
      return const Color(0xFFF5A623);
    case 'rozet':
      return const Color(0xFFFFD166);
    default:
      return AppTheme.primary;
  }
}

String _activityTypeLabel(String type) {
  switch (type) {
    case 'icerik':
      return 'İçerik paylaştın';
    case 'yorum':
      return 'Yorum yaptın';
    case 'begeni':
      return 'Yorum beğendin';
    case 'kayit':
      return 'İçerik kaydettin';
    case 'rozet':
      return 'Rozet kazandın';
    default:
      return 'Aktivite';
  }
}

String _formatRelativeActivityDate(DateTime? date) {
  if (date == null) return 'Tarih yok';

  final difference = DateTime.now().difference(date.toLocal());
  if (difference.inMinutes < 1) return 'Az önce';
  if (difference.inMinutes < 60) return '${difference.inMinutes} dk önce';
  if (difference.inHours < 24) return '${difference.inHours} sa önce';
  if (difference.inDays < 7) return '${difference.inDays} gün önce';
  return _formatDate(date);
}

String _formatNumber(
  double? value, {
  String suffix = '',
  int fractionDigits = 0,
}) {
  if (value == null) return '-';

  final hasFraction = value % 1 != 0;
  final text = hasFraction
      ? value.toStringAsFixed(math.max(1, fractionDigits))
      : value.toStringAsFixed(0);

  return suffix.isEmpty ? text : '$text $suffix';
}

String _formatDate(DateTime? date) {
  if (date == null) return 'Henüz eklenmedi';

  const months = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _targetStatus(double current, double target) {
  final difference = (current - target).abs();
  final formatted = _formatNumber(difference, suffix: 'kg', fractionDigits: 1);

  if (difference < 0.1) return 'Hedef kilodasın';
  if (current > target) return 'Hedefe $formatted kaldı';
  return 'Hedefe $formatted artış kaldı';
}

double? _parseNullableDouble(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed == '-') return null;
  return double.tryParse(trimmed.replaceAll(',', '.'));
}

bool _hasRequiredBiometrics(Map<String, dynamic> data) {
  return data['boy'] != null &&
      data['kilo'] != null &&
      data['hedef_kilo'] != null &&
      (data['fitness_hedefi']?.toString().trim().isNotEmpty ?? false) &&
      data['dogum_tarihi'] != null;
}
