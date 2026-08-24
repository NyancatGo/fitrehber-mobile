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

import '../../core/theme/uygulama_temasi.dart';
import '../../shared/hata_yardimcilari.dart';
import '../../shared/models/profil_model.dart';
import '../../shared/ilk_kurulum_sabitleri.dart';
import '../../shared/oturum_denetleyici.dart';
import 'providers/profil_provider.dart';
import 'widgets/profil_icerik_sekmeleri.dart';

part 'widgets/metrik_karti.dart';
part 'widgets/bolum_basligi.dart';
part 'widgets/bilgi_satiri.dart';
part 'widgets/profil_form_alanlari.dart';
part 'widgets/bildirim_ayarlari_paneli.dart';
part 'widgets/profil_duzenleme_paneli.dart';
part 'widgets/profil_yukleme_iskeleti.dart';
part 'widgets/profil_hata_gorunumu.dart';
part 'widgets/aktivite_haritasi.dart';
part 'widgets/rozet_karti.dart';
part 'helpers/profil_yardimcilari.dart';

/// Kullanıcı profilini gösteren ekran.
///
/// Hem oturum sahibinin kendi profilini hem de başka bir kullanıcının
/// profilini gösterebilir; profil verisi yüklenirken iskelet, hata
/// durumunda ise hata görünümü gösterilir.
class ProfilEkrani extends ConsumerWidget {
  /// `null` ise oturum sahibinin kendi profili; doluysa o kullanıcının profili.
  final int? userId;

  const ProfilEkrani({super.key, this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(oturumDenetleyiciProvider);
    final ownId = session.profile?.id;
    final isOwn = userId == null || (ownId != null && ownId == userId);

    final AsyncValue<ProfilModel> profileState = isOwn
        ? ref.watch(profilProvider)
        : ref.watch(idIleProfilProvider(userId!));

    return Scaffold(
      body: profileState.when(
        data: (profile) =>
            _ProfilIcerigi(profile: profile, isOwnProfile: isOwn),
        loading: () => const _ProfilYuklemeIskeleti(),
        error: (error, stackTrace) => _ProfilHataGorunumu(
          message: kullaniciDostuHata(error),
          isOwnProfile: isOwn,
          viewedUserId: userId,
        ),
      ),
    );
  }
}

class _ProfilIcerigi extends ConsumerWidget {
  final ProfilModel profile;
  final bool isOwnProfile;

  const _ProfilIcerigi({required this.profile, required this.isOwnProfile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: UygulamaTemasi.anaRenk,
      backgroundColor: UygulamaTemasi.yuzey,
      onRefresh: () async {
        if (isOwnProfile) {
          await ref.read(profilProvider.notifier).refresh();
        } else {
          ref.invalidate(idIleProfilProvider(profile.id));
        }
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _ProfilBasligi(profile: profile, isOwnProfile: isOwnProfile),
          ),
          SliverToBoxAdapter(child: _IstatistikSatiri(profile: profile)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            sliver: SliverList.list(
              children: [
                // Biyometri ve hedef ilerlemesi kişisel veridir. Sunucu bu
                // alanları artık yalnız profil sahibine döndürüyor (API
                // ProfilSerializer.SAHIBE_OZEL_ALANLAR); başkasının
                // profilinde kartlar boş görüneceği için burada da
                // gizliyoruz. Web'de aynı kural profil.html'deki BİYOMETRİ
                // bloğunda uygulanıyor.
                if (isOwnProfile) ...[
                  _BiyometrikKartlar(profile: profile),
                  const SizedBox(height: 14),
                  _HedefIlerlemeKarti(profile: profile),
                  const SizedBox(height: 14),
                ],
                if (profile.achievements.isNotEmpty) ...[
                  _RozetlerBolumu(achievements: profile.achievements),
                  const SizedBox(height: 14),
                ],
                if (profile.dailyActivity.days.isNotEmpty) ...[
                  _AktiviteHaritasiBolumu(activity: profile.dailyActivity),
                  const SizedBox(height: 14),
                ],
                if (profile.recentActivities.isNotEmpty) ...[
                  _SonAktivitelerBolumu(activities: profile.recentActivities),
                  const SizedBox(height: 14),
                ],
                _BilgiBolumu(profile: profile),
                const SizedBox(height: 14),
                ProfilIcerikSekmeleri(
                  userId: profile.id,
                  isOwnProfile: isOwnProfile,
                ),
                if (isOwnProfile) ...[
                  const SizedBox(height: 14),
                  _AksiyonBolumu(profile: profile),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilBasligi extends ConsumerWidget {
  final ProfilModel profile;
  final bool isOwnProfile;

  const _ProfilBasligi({required this.profile, required this.isOwnProfile});

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
                  onPressed: () => ref.read(profilProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _ProfilAvatar(profile: profile),
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
          _UyelikRozeti(profile: profile),
        ],
      ),
    );
  }
}

class _ProfilAvatar extends StatelessWidget {
  final ProfilModel profile;

  const _ProfilAvatar({required this.profile});

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
            color: UygulamaTemasi.anaRenk.withValues(alpha: 0.32),
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

class _UyelikRozeti extends StatelessWidget {
  final ProfilModel profile;

  const _UyelikRozeti({required this.profile});

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

class _IstatistikSatiri extends StatelessWidget {
  final ProfilModel profile;

  const _IstatistikSatiri({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: _IstatistikEtiketi(
              icon: Icons.article_outlined,
              label: 'Paylaşım',
              value: profile.postCount.toString(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _IstatistikEtiketi(
              icon: Icons.calendar_month_outlined,
              label: 'Katılım',
              value: _tarihFormatla(profile.joinDate),
            ),
          ),
        ],
      ),
    );
  }
}

class _BiyometrikKartlar extends StatelessWidget {
  final ProfilModel profile;

  const _BiyometrikKartlar({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetrikKarti(
            icon: Icons.height,
            label: 'Boy',
            value: _sayiFormatla(profile.height, suffix: 'cm'),
            caption: profile.height == null ? 'Eklenmedi' : 'Biyometri',
            accent: const Color(0xFF22D3EE),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetrikKarti(
            icon: Icons.monitor_weight_outlined,
            label: 'Kilo',
            value: _sayiFormatla(profile.weight, suffix: 'kg'),
            caption: profile.weight == null ? 'Eklenmedi' : 'Güncel',
            accent: const Color(0xFFF5A623),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetrikKarti(
            icon: Icons.speed_outlined,
            label: 'BMI',
            value: _sayiFormatla(profile.bmi, fractionDigits: 1),
            caption: profile.bmiCategory,
            accent: const Color(0xFF34D399),
          ),
        ),
      ],
    );
  }
}

class _HedefIlerlemeKarti extends StatelessWidget {
  final ProfilModel profile;

  const _HedefIlerlemeKarti({required this.profile});

  @override
  Widget build(BuildContext context) {
    final current = profile.weight;
    final target = profile.targetWeight;
    final start =
        profile.startWeight ?? current; // null ise mevcut kilo = baseline
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
        ? _hedefDurumu(current, target)
        : 'Hedef kilo eklenmedi';
    final progressPercent = (progress * 100).round();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: UygulamaTemasi.yuzey,
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
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF34D399)),
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
                _HedefUcu(
                  label: 'Başlangıç',
                  value: _sayiFormatla(start, suffix: 'kg', fractionDigits: 1),
                  color: Colors.white.withValues(alpha: 0.55),
                ),
                Expanded(
                  child: Center(
                    child: _HedefUcu(
                      label: 'Mevcut',
                      value: _sayiFormatla(
                        current,
                        suffix: 'kg',
                        fractionDigits: 1,
                      ),
                      color: Colors.white,
                      bold: true,
                    ),
                  ),
                ),
                _HedefUcu(
                  label: 'Hedef',
                  value: _sayiFormatla(target, suffix: 'kg', fractionDigits: 1),
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

class _HedefUcu extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;
  final bool alignEnd;

  const _HedefUcu({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
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

class _RozetlerBolumu extends StatelessWidget {
  final List<RozetModel> achievements;

  const _RozetlerBolumu({required this.achievements});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: UygulamaTemasi.yuzey,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BolumBasligi(
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
              return _RozetKutusu(
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

class _SonAktivitelerBolumu extends StatelessWidget {
  final List<ProfilAktiviteModel> activities;

  const _SonAktivitelerBolumu({required this.activities});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: UygulamaTemasi.yuzey,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BolumBasligi(
            icon: Icons.timeline_outlined,
            title: 'Son Aktiviteler',
            subtitle: 'Topluluktaki son hareketlerin',
          ),
          const SizedBox(height: 10),
          ...activities.map((activity) {
            return _ZamanCizelgesiSatiri(
              key: ValueKey('aktivite-${activity.id}'),
              activity: activity,
            );
          }),
        ],
      ),
    );
  }
}

class _ZamanCizelgesiSatiri extends StatelessWidget {
  final ProfilAktiviteModel activity;

  const _ZamanCizelgesiSatiri({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    final accent = _aktiviteTuruRengi(activity.tur);
    final contentTitle = activity.icerikBaslik;

    return InkWell(
      onTap: activity.icerikId == null
          ? null
          : () => context.go('/makale/${activity.icerikId}'),
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
                _aktiviteTuruIkonu(activity.tur),
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
                    activity.detay.isEmpty
                        ? _aktiviteTuruEtiketi(activity.tur)
                        : activity.detay,
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
                    _goreliAktiviteTarihi(activity.tarih),
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

class _BilgiBolumu extends StatelessWidget {
  final ProfilModel profile;

  const _BilgiBolumu({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _BilgiSatiri(
          icon: Icons.notes_outlined,
          title: 'Hakkımda',
          value: profile.bio.isEmpty ? 'Henüz eklenmedi' : profile.bio,
          accent: const Color(0xFF60A5FA),
        ),
        _BilgiSatiri(
          icon: Icons.mail_outline,
          title: 'E-posta',
          value: profile.email.isEmpty ? 'Henüz eklenmedi' : profile.email,
          accent: const Color(0xFFF5A623),
        ),
        _BilgiSatiri(
          icon: Icons.cake_outlined,
          title: 'Doğum Tarihi',
          value: _tarihFormatla(profile.birthDate),
          accent: const Color(0xFFF472B6),
        ),
        _BilgiSatiri(
          icon: Icons.calendar_month_outlined,
          title: 'Katılım Tarihi',
          value: _tarihFormatla(profile.joinDate),
          accent: const Color(0xFF34D399),
        ),
      ],
    );
  }
}

class _AksiyonBolumu extends ConsumerWidget {
  final ProfilModel profile;

  const _AksiyonBolumu({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _AksiyonSatiri(
          icon: Icons.edit_outlined,
          title: 'Profili Düzenle',
          color: UygulamaTemasi.anaRenk,
          onTap: () => _showEditProfileSheet(context, profile),
        ),
        _AksiyonSatiri(
          icon: Icons.notifications_outlined,
          title: 'Bildirim Ayarları',
          color: const Color(0xFF60A5FA),
          onTap: () => _showNotificationSheet(context),
        ),
        _AksiyonSatiri(
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

  await ref.read(oturumDenetleyiciProvider.notifier).cikisYap();
  ref.invalidate(profilProvider);

  if (context.mounted) context.go('/giris');
}
