// Profil ekranı kütüphanesi.
// Ekran; ana scaffold ve sliver yapısını burada tutar, tüm yardımcı
// widget'lar ve fonksiyonlar widgets/ ve helpers/ altındaki part dosyalarında
// tanımlıdır. Tümü aynı kütüphaneye ait olduğundan alt çizgili (private)
// üyeler dosyalar arasında paylaşılır.

import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/hata_yardimcilari.dart';
import '../../shared/models/profil_model.dart';
import '../../shared/session_controller.dart';
import 'providers/profile_provider.dart';
import 'widgets/profile_content_tabs.dart';

part 'widgets/metric_card.dart';
part 'widgets/section_header.dart';
part 'widgets/info_tile.dart';
part 'widgets/profile_form_fields.dart';
part 'widgets/notification_settings_sheet.dart';
part 'widgets/edit_profile_sheet.dart';
part 'widgets/profile_skeleton.dart';
part 'widgets/profile_error.dart';
part 'widgets/activity_heatmap.dart';
part 'widgets/achievement_card.dart';
part 'helpers/profile_helpers.dart';

class ProfileScreen extends ConsumerWidget {
  /// null ise oturum sahibinin kendi profili; doluysa o kullanıcının profili.
  final int? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final ownId = session.profile?.id;
    final isOwn = userId == null || (ownId != null && ownId == userId);

    final AsyncValue<ProfilModel> profileState = isOwn
        ? ref.watch(profileProvider)
        : ref.watch(profileByIdProvider(userId!));

    return Scaffold(
      body: profileState.when(
        data: (profile) =>
            _ProfileContent(profile: profile, isOwnProfile: isOwn),
        loading: () => const _ProfileSkeleton(),
        error: (error, stackTrace) => _ProfileError(
          message: kullaniciDostuHata(error),
          isOwnProfile: isOwn,
          viewedUserId: userId,
        ),
      ),
    );
  }
}

class _ProfileContent extends ConsumerWidget {
  final ProfilModel profile;
  final bool isOwnProfile;

  const _ProfileContent({required this.profile, required this.isOwnProfile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: AppTheme.primary,
      backgroundColor: AppTheme.surface,
      onRefresh: () async {
        if (isOwnProfile) {
          await ref.read(profileProvider.notifier).refresh();
        } else {
          ref.invalidate(profileByIdProvider(profile.id));
        }
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _ProfileHeader(profile: profile, isOwnProfile: isOwnProfile),
          ),
          SliverToBoxAdapter(child: _StatsRow(profile: profile)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            sliver: SliverList.list(
              children: [
                _BiometricCards(profile: profile),
                const SizedBox(height: 14),
                _GoalProgressCard(profile: profile),
                const SizedBox(height: 14),
                if (profile.achievements.isNotEmpty) ...[
                  _AchievementsSection(achievements: profile.achievements),
                  const SizedBox(height: 14),
                ],
                if (profile.dailyActivity.days.isNotEmpty) ...[
                  _ActivityHeatmapSection(activity: profile.dailyActivity),
                  const SizedBox(height: 14),
                ],
                if (profile.recentActivities.isNotEmpty) ...[
                  _RecentActivitiesSection(
                    activities: profile.recentActivities,
                  ),
                  const SizedBox(height: 14),
                ],
                _InfoSection(profile: profile),
                const SizedBox(height: 14),
                ProfileContentTabs(
                  userId: profile.id,
                  isOwnProfile: isOwnProfile,
                ),
                if (isOwnProfile) ...[
                  const SizedBox(height: 14),
                  _ActionSection(profile: profile),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends ConsumerWidget {
  final ProfilModel profile;
  final bool isOwnProfile;

  const _ProfileHeader({required this.profile, required this.isOwnProfile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, topPadding + 18, 24, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF121722), Color(0xFF203147), Color(0xFF5A3813)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (!isOwnProfile)
                IconButton.filledTonal(
                  tooltip: 'Geri',
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back),
                ),
              if (!isOwnProfile) const SizedBox(width: 8),
              Text(
                isOwnProfile ? 'Profil' : 'Kullanıcı Profili',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              if (isOwnProfile)
                IconButton.filledTonal(
                  tooltip: 'Profili yenile',
                  onPressed: () => ref.read(profileProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _ProfileAvatar(profile: profile),
          const SizedBox(height: 18),
          Text(
            profile.displayName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 26,
              height: 1.1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          if (profile.username.isNotEmpty)
            Text(
              '@${profile.username}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 14),
          _MembershipBadge(profile: profile),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final ProfilModel profile;

  const _ProfileAvatar({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 124,
      height: 124,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD166), Color(0xFFF5A623), Color(0xFF22D3EE)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.32),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: profile.avatarUrl == null
            ? _AvatarFallback(initials: profile.initials)
            : CachedNetworkImage(
                imageUrl: profile.avatarUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    _AvatarFallback(initials: profile.initials),
                errorWidget: (context, url, error) =>
                    _AvatarFallback(initials: profile.initials),
              ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final String initials;

  const _AvatarFallback({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF111827),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _MembershipBadge extends StatelessWidget {
  final ProfilModel profile;

  const _MembershipBadge({required this.profile});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    final IconData icon;

    if (profile.isSuperuser) {
      color = const Color(0xFFFFD166);
      label = 'Admin';
      icon = Icons.shield_outlined;
    } else if (profile.isStaff) {
      color = const Color(0xFF60A5FA);
      label = 'Yetkili';
      icon = Icons.verified_user_outlined;
    } else {
      color = const Color(0xFF94A3B8);
      label = 'Standart Üye';
      icon = Icons.person_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final ProfilModel profile;

  const _StatsRow({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: _StatChip(
              icon: Icons.article_outlined,
              label: 'Paylaşım',
              value: profile.postCount.toString(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatChip(
              icon: Icons.calendar_month_outlined,
              label: 'Katılım',
              value: _formatDate(profile.joinDate),
            ),
          ),
        ],
      ),
    );
  }
}

class _BiometricCards extends StatelessWidget {
  final ProfilModel profile;

  const _BiometricCards({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            icon: Icons.height,
            label: 'Boy',
            value: _formatNumber(profile.height, suffix: 'cm'),
            caption: profile.height == null ? 'Eklenmedi' : 'Biyometri',
            accent: const Color(0xFF22D3EE),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            icon: Icons.monitor_weight_outlined,
            label: 'Kilo',
            value: _formatNumber(profile.weight, suffix: 'kg'),
            caption: profile.weight == null ? 'Eklenmedi' : 'Güncel',
            accent: const Color(0xFFF5A623),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            icon: Icons.speed_outlined,
            label: 'BMI',
            value: _formatNumber(profile.bmi, fractionDigits: 1),
            caption: profile.bmiCategory,
            accent: const Color(0xFF34D399),
          ),
        ),
      ],
    );
  }
}

class _GoalProgressCard extends StatelessWidget {
  final ProfilModel profile;

  const _GoalProgressCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final current = profile.weight;
    final target = profile.targetWeight;
    final start = profile.startWeight ?? current; // null ise mevcut kilo = baseline
    final hasGoal = current != null && target != null && target > 0;

    // Yeni progress mantığı:
    //   toplam_yol  = |başlangıç - hedef|
    //   gidilen_yol = |başlangıç - mevcut| (yön doğruysa)
    //   progress    = gidilen / toplam (0..1)
    // Kullanıcı ters yöne giderse progress 0; hedefi geçtiyse 1.
    double progress = 0.0;
    if (hasGoal && start != null) {
      final toplamYol = (start - target).abs();
      if (toplamYol < 0.05) {
        // Başlangıç = hedef (zaten hedefte) — bar full göster.
        progress = 1.0;
      } else {
        // Hedef yönü: start > target → kilo vermek; start < target → kilo almak.
        final hedefAsagi = target < start;
        final gidilen = hedefAsagi ? (start - current) : (current - start);
        progress = (gidilen / toplamYol).clamp(0.0, 1.0).toDouble();
      }
    }

    final targetText = hasGoal
        ? _targetStatus(current, target)
        : 'Hedef kilo eklenmedi';
    final progressPercent = (progress * 100).round();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.flag_outlined,
                  color: Color(0xFFF97316),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hedef ve İlerleme',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      profile.goal.isEmpty
                          ? 'Hedef belirlenmedi'
                          : profile.goal,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Progress bar + sağında yüzde
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 10,
                    value: progress,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: const AlwaysStoppedAnimation(
                      Color(0xFF34D399),
                    ),
                  ),
                ),
              ),
              if (hasGoal) ...[
                const SizedBox(width: 12),
                Text(
                  '%$progressPercent',
                  style: const TextStyle(
                    color: Color(0xFF34D399),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          // Başlangıç / Mevcut / Hedef üçlüsü
          if (hasGoal && start != null) ...[
            Row(
              children: [
                _GoalEndpoint(
                  label: 'Başlangıç',
                  value: _formatNumber(start, suffix: 'kg', fractionDigits: 1),
                  color: Colors.white.withValues(alpha: 0.55),
                ),
                Expanded(
                  child: Center(
                    child: _GoalEndpoint(
                      label: 'Mevcut',
                      value: _formatNumber(
                        current,
                        suffix: 'kg',
                        fractionDigits: 1,
                      ),
                      color: Colors.white,
                      bold: true,
                    ),
                  ),
                ),
                _GoalEndpoint(
                  label: 'Hedef',
                  value: _formatNumber(
                    target,
                    suffix: 'kg',
                    fractionDigits: 1,
                  ),
                  color: const Color(0xFF34D399),
                  alignEnd: true,
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  targetText,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalEndpoint extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;
  final bool alignEnd;

  const _GoalEndpoint({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: bold ? 15 : 13,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _AchievementsSection extends StatelessWidget {
  final List<AchievementModel> achievements;

  const _AchievementsSection({required this.achievements});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.workspace_premium_outlined,
            title: 'Başarılar',
            subtitle:
                '${achievements.where((item) => item.isUnlocked).length}/${achievements.length} açık',
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: achievements.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 140,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.88,
            ),
            itemBuilder: (context, index) {
              final achievement = achievements[index];
              return _AchievementTile(
                key: ValueKey('rozet-${achievement.key}'),
                achievement: achievement,
                onTap: () => _showAchievementSheet(context, achievement),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RecentActivitiesSection extends StatelessWidget {
  final List<ProfileActivityModel> activities;

  const _RecentActivitiesSection({required this.activities});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.timeline_outlined,
            title: 'Son Aktiviteler',
            subtitle: 'Topluluktaki son hareketlerin',
          ),
          const SizedBox(height: 10),
          ...activities.map((activity) {
            return _TimelineTile(
              key: ValueKey('aktivite-${activity.id}'),
              activity: activity,
            );
          }),
        ],
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final ProfileActivityModel activity;

  const _TimelineTile({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    final accent = _activityTypeColor(activity.type);
    final contentTitle = activity.contentTitle;

    return InkWell(
      onTap: activity.contentId == null
          ? null
          : () => context.go('/makale/${activity.contentId}'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _activityTypeIcon(activity.type),
                color: accent,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.detail.isEmpty
                        ? _activityTypeLabel(activity.type)
                        : activity.detail,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  if (contentTitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      contentTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.56),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _formatRelativeActivityDate(activity.date),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.42),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final ProfilModel profile;

  const _InfoSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InfoTile(
          icon: Icons.notes_outlined,
          title: 'Hakkımda',
          value: profile.bio.isEmpty ? 'Henüz eklenmedi' : profile.bio,
          accent: const Color(0xFF60A5FA),
        ),
        _InfoTile(
          icon: Icons.mail_outline,
          title: 'E-posta',
          value: profile.email.isEmpty ? 'Henüz eklenmedi' : profile.email,
          accent: const Color(0xFFF5A623),
        ),
        _InfoTile(
          icon: Icons.cake_outlined,
          title: 'Doğum Tarihi',
          value: _formatDate(profile.birthDate),
          accent: const Color(0xFFF472B6),
        ),
        _InfoTile(
          icon: Icons.calendar_month_outlined,
          title: 'Katılım Tarihi',
          value: _formatDate(profile.joinDate),
          accent: const Color(0xFF34D399),
        ),
      ],
    );
  }
}

class _ActionSection extends ConsumerWidget {
  final ProfilModel profile;

  const _ActionSection({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _ActionTile(
          icon: Icons.edit_outlined,
          title: 'Profili Düzenle',
          color: AppTheme.primary,
          onTap: () => _showEditProfileSheet(context, profile),
        ),
        _ActionTile(
          icon: Icons.notifications_outlined,
          title: 'Bildirim Ayarları',
          color: const Color(0xFF60A5FA),
          onTap: () => _showNotificationSheet(context),
        ),
        _ActionTile(
          icon: Icons.logout,
          title: 'Çıkış Yap',
          color: const Color(0xFFEF4444),
          onTap: () => _confirmLogout(context, ref),
        ),
      ],
    );
  }
}

Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Oturumunu kapatmak istiyor musun?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Çıkış Yap'),
          ),
        ],
      );
    },
  );

  if (confirmed != true || !context.mounted) return;

  await ref.read(sessionControllerProvider.notifier).logout();
  ref.invalidate(profileProvider);

  if (context.mounted) context.go('/giris');
}
