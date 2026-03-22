import 'package:go_router/go_router.dart';
import '../screens/audio_list_screen.dart';
import '../screens/audio_player_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const AudioListScreen()),
    GoRoute(
      path: '/player',
      builder: (context, state) => const AudioPlayerScreen(),
    ),
  ],
);
