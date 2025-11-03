import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app_router.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize just_audio_background for lockscreen controls and background playback
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.audiobook.channel.audio',
    androidNotificationChannelName: 'Audiobook Playback',
    androidNotificationOngoing: true,
    preloadArtwork: true,
  );

  runApp(const ProviderScope(child: AudiobookApp()));
}

class AudiobookApp extends ConsumerWidget {
  const AudiobookApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Audiobook',
      theme: AppTheme.light(),
      routerConfig: appRouter,
    );
  }
}

