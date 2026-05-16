import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/auth_service.dart';
import '../../shared/models/profil_model.dart';
import 'providers/profile_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileProvider);

    return Scaffold(
      body: profileState.when(
        data: (profile) => _ProfileContent(profile: profile),
        loading: () => const _ProfileSkeleton(),
        error: (error, stackTrace) => _ProfileError(message: error.toString()),
      ),
    );
  }
}

class _ProfileContent extends ConsumerWidget {
  final ProfilModel profile;

  const _ProfileContent({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: AppTheme.primary,
      backgroundColor: AppTheme.surface,
      onRefresh: () => ref.read(profileProvider.notifier).refresh(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _ProfileHeader(profile: profile)),
          SliverToBoxAdapter(child: _StatsRow(profile: profile)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            sliver: SliverList.list(
              children: [
                _BiometricCards(profile: profile),
                const SizedBox(height: 14),
                _GoalProgressCard(profile: profile),
                const SizedBox(height: 14),
                _InfoSection(profile: profile),
                const SizedBox(height: 14),
                _ActionSection(profile: profile),
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

  const _ProfileHeader({required this.profile});

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
              const Text(
                'Profil',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const Spacer(),
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

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.5), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
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

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String caption;
  final Color accent;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 134,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const Spacer(),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.64),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.46),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
    final hasGoal = current != null && target != null && target > 0;
    final difference = hasGoal ? (current - target).abs() : null;
    final baseline = hasGoal ? math.max(current, target) : 1.0;
    final progress = hasGoal
        ? (1 - (difference! / baseline)).clamp(0.06, 1.0).toDouble()
        : 0.0;
    final targetText = hasGoal
        ? _targetStatus(current, target)
        : 'Hedef kilo eklenmedi';

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
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF34D399)),
            ),
          ),
          const SizedBox(height: 12),
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
              if (target != null)
                Text(
                  _formatNumber(target, suffix: 'kg'),
                  style: const TextStyle(
                    color: Color(0xFF34D399),
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
        ],
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

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color accent;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accent, size: 21),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.56),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: title == 'Hakkımda' ? 3 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 21),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: color == const Color(0xFFEF4444) ? color : Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: Colors.white.withValues(alpha: 0.38),
        ),
      ),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;

    return Shimmer.fromColors(
      baseColor: const Color(0xFF1A1D27),
      highlightColor: const Color(0xFF2A2D37),
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, topPadding + 16, 16, 24),
        children: [
          const _SkeletonBox(height: 244, radius: 30),
          const SizedBox(height: 18),
          Row(
            children: const [
              Expanded(child: _SkeletonBox(height: 134, radius: 18)),
              SizedBox(width: 10),
              Expanded(child: _SkeletonBox(height: 134, radius: 18)),
              SizedBox(width: 10),
              Expanded(child: _SkeletonBox(height: 134, radius: 18)),
            ],
          ),
          const SizedBox(height: 14),
          const _SkeletonBox(height: 160, radius: 18),
          const SizedBox(height: 14),
          const _SkeletonBox(height: 72, radius: 16),
          const SizedBox(height: 10),
          const _SkeletonBox(height: 72, radius: 16),
          const SizedBox(height: 10),
          const _SkeletonBox(height: 72, radius: 16),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double height;
  final double radius;

  const _SkeletonBox({required this.height, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _ProfileError extends ConsumerWidget {
  final String message;

  const _ProfileError({required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 74,
                height: 74,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_off_outlined,
                  color: Color(0xFFEF4444),
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Profil bilgileri alınamadı',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.62)),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => ref.read(profileProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar Dene'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => context.go('/giris'),
                child: const Text('Giriş Ekranına Dön'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  final ProfilModel profile;

  const _EditProfileSheet({required this.profile});

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _bioController;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  late final TextEditingController _targetWeightController;
  late final TextEditingController _goalController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _bioController = TextEditingController(text: widget.profile.bio);
    _heightController = TextEditingController(
      text: _formatNumber(widget.profile.height),
    );
    _weightController = TextEditingController(
      text: _formatNumber(widget.profile.weight),
    );
    _targetWeightController = TextEditingController(
      text: _formatNumber(widget.profile.targetWeight),
    );
    _goalController = TextEditingController(text: widget.profile.goal);
  }

  @override
  void dispose() {
    _bioController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _targetWeightController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;

    setState(() => _saving = true);

    try {
      await ref.read(profileProvider.notifier).updateProfile({
        'hakkinda': _bioController.text.trim(),
        'boy': _parseNullableDouble(_heightController.text),
        'kilo': _parseNullableDouble(_weightController.text),
        'hedef_kilo': _parseNullableDouble(_targetWeightController.text),
        'fitness_hedefi': _goalController.text.trim(),
      });

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Profil güncellendi.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(18, 18, 18, bottomInset + 18),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Profili Düzenle',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bioController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Hakkımda',
                prefixIcon: Icon(Icons.notes_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _NumberField(
                    controller: _heightController,
                    label: 'Boy',
                    suffix: 'cm',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _NumberField(
                    controller: _weightController,
                    label: 'Kilo',
                    suffix: 'kg',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _NumberField(
              controller: _targetWeightController,
              label: 'Hedef Kilo',
              suffix: 'kg',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _goalController,
              decoration: const InputDecoration(
                labelText: 'Hedef',
                prefixIcon: Icon(Icons.flag_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String suffix;

  const _NumberField({
    required this.controller,
    required this.label,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _NotificationSettingsSheet extends StatefulWidget {
  const _NotificationSettingsSheet();

  @override
  State<_NotificationSettingsSheet> createState() =>
      _NotificationSettingsSheetState();
}

class _NotificationSettingsSheetState
    extends State<_NotificationSettingsSheet> {
  bool workout = true;
  bool nutrition = true;
  bool weekly = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 18),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Bildirim Ayarları',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            value: workout,
            onChanged: (value) => setState(() => workout = value),
            title: const Text('Antrenman hatırlatmaları'),
          ),
          SwitchListTile(
            value: nutrition,
            onChanged: (value) => setState(() => nutrition = value),
            title: const Text('Beslenme bildirimleri'),
          ),
          SwitchListTile(
            value: weekly,
            onChanged: (value) => setState(() => weekly = value),
            title: const Text('Haftalık ilerleme özeti'),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.of(context).pop();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Bildirim ayarları kaydedildi.'),
                  ),
                );
              },
              child: const Text('Kaydet'),
            ),
          ),
        ],
      ),
    );
  }
}

void _showEditProfileSheet(BuildContext context, ProfilModel profile) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _EditProfileSheet(profile: profile),
  );
}

void _showNotificationSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => const _NotificationSettingsSheet(),
  );
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

  await AuthService().logout();
  ref.invalidate(profileProvider);

  if (context.mounted) context.go('/giris');
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
