// Uygulama içi sayfa geçişleri go_router ile yönetilir.
// initialLocation: uygulama açılınca ilk gidilen sayfa.
// Her GoRoute bir URL path'i ile bir ekranı eşleştirir.

import 'package:go_router/go_router.dart';
import '../../features/home/home_screen.dart';
import '../../features/categories/categories_screen.dart';
import '../../features/article/article_screen.dart';
import '../../features/forum/forum_screen.dart';
import '../../features/ai_assistant/ai_assistant_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/giris', // Uygulama her zaman giriş ekranından başlar
  routes: [
    // Kimlik doğrulama
    GoRoute(path: '/giris', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/kayit', builder: (context, state) => const RegisterScreen()),

    // Ana ekranlar
    GoRoute(path: '/',            builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/kategoriler', builder: (context, state) => const CategoriesScreen()),
    GoRoute(path: '/forum',       builder: (context, state) => const ForumScreen()),
    GoRoute(path: '/asistan',     builder: (context, state) => const AiAssistantScreen()),
    GoRoute(path: '/profil',      builder: (context, state) => const ProfileScreen()),
    GoRoute(path: '/arama',       builder: (context, state) => const SearchScreen()),

    // Makale detay sayfası — URL'den id parametresi alır (/makale/42 gibi)
    GoRoute(
      path: '/makale/:id',
      builder: (context, state) => ArticleScreen(
        id: int.parse(state.pathParameters['id']!),
      ),
    ),
  ],
);
