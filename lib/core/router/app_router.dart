import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/app_session_controller.dart';
import '../../features/auth/application/app_session_state.dart';
import '../../features/auth/presentation/startup_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/profile/presentation/onboarding_screen.dart';
import 'route_names.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final sessionState = ref.watch(appSessionControllerProvider);
  final router = GoRouter(
    initialLocation: RoutePaths.startup,
    redirect: (context, state) {
      final target = switch (sessionState) {
        AppSessionReady() => RoutePaths.home,
        AppSessionNeedsProfile() => RoutePaths.onboarding,
        _ => RoutePaths.startup,
      };
      return state.matchedLocation == target ? null : target;
    },
    routes: [
      GoRoute(
        name: RouteNames.startup,
        path: RoutePaths.startup,
        builder: (context, state) => const StartupScreen(),
      ),
      GoRoute(
        name: RouteNames.onboarding,
        path: RoutePaths.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        name: RouteNames.home,
        path: RoutePaths.home,
        builder: (context, state) => const HomeScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
