import 'package:go_router/go_router.dart';
import 'package:ohhell_client/src/screens/game_screen.dart';
import 'package:ohhell_client/src/screens/home_screen.dart';
import 'package:ohhell_client/src/screens/lobby_screen.dart';
import 'package:ohhell_client/src/screens/score_screen.dart';
import 'package:ohhell_client/src/screens/splash_screen.dart';

final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => const SplashScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (_, __) => const HomeScreen(),
    ),
    GoRoute(
      path: '/lobby/:roomCode',
      builder: (context, state) => LobbyScreen(
        roomCode: state.pathParameters['roomCode']!,
      ),
    ),
    GoRoute(
      path: '/game/:roomCode',
      builder: (context, state) => GameScreen(
        roomCode: state.pathParameters['roomCode']!,
      ),
    ),
    GoRoute(
      path: '/scores/:roomCode',
      builder: (context, state) => ScoreScreen(
        roomCode: state.pathParameters['roomCode']!,
      ),
    ),
  ],
);
