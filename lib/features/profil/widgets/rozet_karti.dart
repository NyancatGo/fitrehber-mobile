// Profil ekranı: başarı (rozet) kartı ve detay alt sayfası.
part of '../profil_ekrani.dart';

class _RozetKutusu extends StatelessWidget {
  final RozetModel achievement;
  final VoidCallback onTap;

  const _RozetKutusu({
    super.key,
    required this.achievement,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = achievement.isUnlocked
        ? UygulamaTemasi.anaRenk
        : UygulamaTemasi.ikincilMetin;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: UygulamaTemasi.yuzey,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: achievement.isUnlocked
                ? UygulamaTemasi.anaRenk
                : UygulamaTemasi.cizgi,
          ),
        ),
        child: Column(
          children: [
            Icon(_rozetIkonu(achievement.icon), color: accent, size: 28),
            const SizedBox(height: 8),
            Text(
              achievement.name.isEmpty ? achievement.key : achievement.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: achievement.isUnlocked
                    ? UygulamaTemasi.anaMetin
                    : UygulamaTemasi.ikincilMetin,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 5,
                value: achievement.progress / 100,
                backgroundColor: UygulamaTemasi.cizgi,
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showAchievementSheet(BuildContext context, RozetModel achievement) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: UygulamaTemasi.yuzey,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      final accent = achievement.isUnlocked
          ? UygulamaTemasi.anaRenk
          : UygulamaTemasi.ikincilMetin;

      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: UygulamaTemasi.cizgi,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_rozetIkonu(achievement.icon), color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        achievement.name.isEmpty
                            ? achievement.key
                            : achievement.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        achievement.description,
                        style: TextStyle(
                          color: UygulamaTemasi.ikincilMetin,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ...achievement.metrics.map((metric) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            metric.label,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          '${metric.current} / ${metric.target}',
                          style: TextStyle(
                            color: UygulamaTemasi.ikincilMetin,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: metric.progress / 100,
                        backgroundColor: UygulamaTemasi.cizgi,
                        valueColor: AlwaysStoppedAnimation(accent),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      );
    },
  );
}
