// ---------------------------------------------------------------------------
// UYGULAMA YÖNLENDİRİCİSİ (ROUTER)
// ---------------------------------------------------------------------------
// Uygulamadaki ekran adresleri ve oturum koruması burada tanımlanır.
// Router'ın ana görevi, oturum yüklenirken, giriş yapılmamışken ve ilk kurulum
// eksikken kullanıcıyı doğru ekrana zorlamaktır. Kimlik ekranları çıkış
// yapılmışken erişilebilir kalır.
// ---------------------------------------------------------------------------

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/asistan/asistan_ekrani.dart';
import '../../features/icerik/icerik_ekrani.dart';
import '../../features/icerik/odakli_yorum_ekrani.dart';
import '../../features/kimlik/giris_ekrani.dart';
import '../../features/kimlik/kayit_ekrani.dart';
import '../../features/kimlik/eposta_dogrulama_ekrani.dart';
import '../../features/kimlik/sifremi_unuttum_ekrani.dart';
import '../../features/kategoriler/kategoriler_ekrani.dart';
import '../../features/forum/forum_ekrani.dart';
import '../../features/forum/soru_sor_ekrani.dart';
import '../../features/ana_sayfa/ana_sayfa_ekrani.dart';
import '../../features/beslenme/beslenme_ekrani.dart';
import '../../features/ilk_kurulum/ilk_kurulum_ekrani.dart';
import '../../features/profil/profil_ekrani.dart';
import '../../features/arama/arama_ekrani.dart';
import '../../shared/oturum_denetleyici.dart';
import '../../shared/widgets/oturum_yukleme.dart';

/// Uygulamanın `GoRouter` örneğini sağlayan Riverpod provider'ı.
///
/// Oturum durumunu (`oturumDenetleyiciProvider`) izler; oturum bilgisi
/// değiştiğinde router yeniden oluşturulur ve koruma kuralları tekrar işler.
final uygulamaYonlendiriciProvider = Provider<GoRouter>((ref) {
  // Güncel oturum durumu: yükleniyor mu, giriş var mı, ilk kurulum tamam mı?
  final session = ref.watch(oturumDenetleyiciProvider);

  return GoRouter(
    // İlk açılışta token/profil henüz okunmadığı için yükleme ekranıyla başlanır.
    initialLocation: '/session-loading',

    // -----------------------------------------------------------------------
    // YÖNLENDİRME KORUMASI
    // Öncelik sırası önemlidir: yükleme -> auth -> ilk kurulum -> ana uygulama.
    // `null` geçişe izin verir; string dönerse kullanıcı o adrese alınır.
    // -----------------------------------------------------------------------
    redirect: (context, state) {
      final path = state.uri.path;

      // E-posta doğrulama ve şifremi unuttum ekranları da auth akışıdır;
      // bu yüzden çıkış yapılmışken erişilebilir kalırlar.
      final isLoadingPath = path == '/session-loading';
      final isAuthPath =
          path == '/giris' ||
          path == '/kayit' ||
          path == '/email-dogrulama' ||
          path == '/sifremi-unuttum';
      final isOnboardingPath = path == '/onboarding';

      // 1) Oturum bilgisi okunuyorsa korumalı ekranları yükleme ekranına al.
      if (session.isLoading) {
        if (isLoadingPath || isAuthPath || isOnboardingPath) return null;
        return '/session-loading';
      }

      // 2) Giriş yoksa sadece auth ekranlarına izin ver.
      if (!session.oturumVarMi) {
        return isAuthPath ? null : '/giris';
      }

      // 3) Giriş var ama ilk kurulum eksikse kurulum ekranına zorla.
      if (!session.isOnboarded) {
        return isOnboardingPath ? null : '/onboarding';
      }

      // 4) Oturum hazırsa auth/kurulum/yükleme ekranlarına geri dönme.
      if (isAuthPath || isOnboardingPath || isLoadingPath) return '/';

      // Diğer tüm durumlarda geçişe izin ver.
      return null;
    },

    // -----------------------------------------------------------------------
    // SAYFA TANIMLARI
    // Her `GoRoute`, bir adresi (path) bir ekran widget'ına bağlar.
    // -----------------------------------------------------------------------
    routes: [
      // Oturum bilgisi okunurken gösterilen açılış/yükleme ekranı.
      GoRoute(
        path: '/session-loading',
        builder: (context, state) => const OturumYuklemeEkrani(),
      ),

      // --- Kimlik doğrulama ekranları ---
      GoRoute(path: '/giris', builder: (context, state) => const GirisEkrani()),
      GoRoute(path: '/kayit', builder: (context, state) => const KayitEkrani()),
      GoRoute(
        path: '/email-dogrulama',
        builder: (context, state) {
          // Doğrulama ekranı, hangi e-postanın doğrulanacağını adres
          // parametresinden (?email=...) alır.
          final email = state.uri.queryParameters['email'] ?? '';
          return EpostaDogrulamaEkrani(email: email);
        },
      ),
      GoRoute(
        path: '/sifremi-unuttum',
        builder: (context, state) => const SifremiUnuttumEkrani(),
      ),

      // İlk kurulum (boy, kilo, hedef vb.) ekranı.
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const IlkKurulumEkrani(),
      ),

      // --- Ana uygulama ekranları ---
      GoRoute(path: '/', builder: (context, state) => const AnaSayfaEkrani()),
      GoRoute(
        path: '/kategoriler',
        builder: (context, state) => const KategorilerEkrani(),
      ),
      GoRoute(path: '/forum', builder: (context, state) => const ForumEkrani()),
      GoRoute(
        path: '/forum/soru-sor',
        builder: (context, state) => const SoruSorEkrani(),
      ),
      GoRoute(
        path: '/asistan',
        builder: (context, state) => const AsistanEkrani(),
      ),
      GoRoute(
        path: '/beslenme',
        builder: (context, state) => const BeslenmeEkrani(),
      ),

      // Oturum sahibinin kendi profili.
      GoRoute(
        path: '/profil',
        builder: (context, state) => const ProfilEkrani(),
      ),
      // Başka bir kullanıcının profili (adresteki :id parametresiyle).
      GoRoute(
        path: '/profil/:id',
        builder: (context, state) =>
            ProfilEkrani(userId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(path: '/arama', builder: (context, state) => const AramaEkrani()),

      // Belirli bir yoruma odaklanan ekran (bildirimden/derin bağlantıdan gelinir).
      GoRoute(
        path: '/makale/:id/yorum/:yorumId',
        builder: (context, state) => OdakliYorumEkrani(
          icerikId: int.parse(state.pathParameters['id']!),
          focusCommentId: int.parse(state.pathParameters['yorumId']!),
        ),
      ),
      // Tek bir makale/içerik detayı.
      GoRoute(
        path: '/makale/:id',
        builder: (context, state) =>
            IcerikEkrani(id: int.parse(state.pathParameters['id']!)),
      ),
    ],
  );
});
