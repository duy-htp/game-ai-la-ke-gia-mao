import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/app_session_controller.dart';
import '../../features/auth/application/app_session_state.dart';
import '../../features/auth/presentation/startup_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/profile/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/room/presentation/create_room_screen.dart';
import '../../features/room/presentation/join_room_screen.dart';
import '../../features/room/presentation/room_screen.dart';
import '../../features/game/presentation/role_reveal_screen.dart';
import '../../features/game/presentation/clue_screen.dart';
import '../../features/game/presentation/discussion_screen.dart';
import '../../features/game/presentation/voting_screen.dart';
import '../../features/game/presentation/vote_result_screen.dart';
import '../../features/game/presentation/final_guess_screen.dart';
import '../../features/game/presentation/game_result_screen.dart';
import '../../features/game/domain/game_status.dart';
import 'route_names.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // Profile/stat refreshes must not recreate GoRouter and throw the user back
  // to its initial location. Only routing-relevant session changes invalidate
  // this provider.
  ref.watch(
    appSessionControllerProvider.select(
      (value) => switch (value) {
        AppSessionReady(:final room, :final game) => (
          value.runtimeType,
          room?.roomId,
          room?.revision,
          game?.gameId,
          game?.revision,
          game?.status,
        ),
        _ => (value.runtimeType, null, null, null, null, null),
      },
    ),
  );
  final sessionState = ref.read(appSessionControllerProvider);
  final router = GoRouter(
    initialLocation: RoutePaths.startup,
    redirect: (context, state) {
      return switch (sessionState) {
        AppSessionReady(:final game) when game != null =>
          state.matchedLocation == RoutePaths.game ? null : RoutePaths.game,
        AppSessionReady(:final room) when room != null =>
          state.matchedLocation == RoutePaths.room ? null : RoutePaths.room,
        AppSessionReady() => switch (state.matchedLocation) {
          RoutePaths.home ||
          RoutePaths.createRoom ||
          RoutePaths.joinRoom => null,
          RoutePaths.profile => null,
          _ => RoutePaths.home,
        },
        AppSessionNeedsProfile() =>
          state.matchedLocation == RoutePaths.onboarding
              ? null
              : RoutePaths.onboarding,
        _ =>
          state.matchedLocation == RoutePaths.startup
              ? null
              : RoutePaths.startup,
      };
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
      GoRoute(
        name: RouteNames.profile,
        path: RoutePaths.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        name: RouteNames.createRoom,
        path: RoutePaths.createRoom,
        builder: (context, state) => const CreateRoomScreen(),
      ),
      GoRoute(
        name: RouteNames.joinRoom,
        path: RoutePaths.joinRoom,
        builder: (context, state) => const JoinRoomScreen(),
      ),
      GoRoute(
        name: RouteNames.room,
        path: RoutePaths.room,
        builder: (context, state) => const RoomScreen(),
      ),
      GoRoute(
        name: RouteNames.game,
        path: RoutePaths.game,
        builder: (context, state) {
          final current = ref.read(appSessionControllerProvider);
          final game = current is AppSessionReady ? current.game : null;
          return switch (game?.status) {
            GameStatus.clue => const ClueScreen(),
            GameStatus.discussion => const DiscussionScreen(),
            GameStatus.voting => const VotingScreen(),
            GameStatus.voteResult => const VoteResultScreen(),
            GameStatus.finalGuess => const FinalGuessScreen(),
            GameStatus.result => const GameResultScreen(),
            _ => const RoleRevealScreen(),
          };
        },
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
