import 'package:go_router/go_router.dart';

import 'screens/home/home_screen.dart';
import 'screens/player/player_screen.dart';
import 'screens/transcript/transcript_screen.dart';
import 'screens/summary/summary_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/player/:bookId',
      builder: (context, state) {
        final id = state.pathParameters['bookId']!;
        return PlayerScreen(bookId: id);
      },
    ),
    GoRoute(
      path: '/transcript/:bookId',
      builder: (context, state) => TranscriptScreen(bookId: state.pathParameters['bookId']!),
    ),
    GoRoute(
      path: '/summary/:bookId',
      builder: (context, state) => SummaryScreen(bookId: state.pathParameters['bookId']!),
    ),
  ],
);
