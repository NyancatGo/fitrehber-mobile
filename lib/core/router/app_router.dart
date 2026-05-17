import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/ai_assistant/ai_assistant_screen.dart';
import '../../features/article/article_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/categories/categories_screen.dart';
import '../../features/forum/forum_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/nutrition/nutrition_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/search/search_screen.dart';
import '../../shared/session_controller.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(sessionControllerProvider);

  return GoRouter(
    initialLocation: '/giris',
    redirect: (context, state) {
      final path = state.uri.path;
      final isAuthPath = path == '/giris' || path == '/kayit';
      final isOnboardingPath = path == '/onboarding';

      if (session.isLoading) return null;

      if (!session.isLoggedIn) {
        return isAuthPath ? null : '/giris';
      }

      if (!session.isOnboarded) {
        return isOnboardingPath ? null : '/onboarding';
      }

      if (isAuthPath || isOnboardingPath) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/giris', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/kayit',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/kategoriler',
        builder: (context, state) => const CategoriesScreen(),
      ),
      GoRoute(path: '/forum', builder: (context, state) => const ForumScreen()),
      GoRoute(
        path: '/asistan',
        builder: (context, state) => const AiAssistantScreen(),
      ),
      GoRoute(
        path: '/beslenme',
        builder: (context, state) => const NutritionScreen(),
      ),
      GoRoute(
        path: '/profil',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/profil/:id',
        builder: (context, state) => ProfileScreen(
          userId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/arama',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/makale/:id',
        builder: (context, state) =>
            ArticleScreen(id: int.parse(state.pathParameters['id']!)),
      ),
    ],
  );
});
