import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/home_screen.dart';
import 'route_names.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: RoutePaths.home,
    routes: [
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
