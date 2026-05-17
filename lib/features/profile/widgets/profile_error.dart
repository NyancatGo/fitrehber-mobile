// Profil verisi alınamadığında gösterilen hata görünümü.
part of '../profile_screen.dart';

class _ProfileError extends ConsumerWidget {
  final String message;
  final bool isOwnProfile;
  final int? viewedUserId;

  const _ProfileError({
    required this.message,
    required this.isOwnProfile,
    required this.viewedUserId,
  });

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
                onPressed: () {
                  if (isOwnProfile) {
                    ref.read(profileProvider.notifier).refresh();
                  } else if (viewedUserId != null) {
                    ref.invalidate(profileByIdProvider(viewedUserId!));
                  }
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar Dene'),
              ),
              if (isOwnProfile) ...[
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => context.go('/giris'),
                  child: const Text('Giriş Ekranına Dön'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
