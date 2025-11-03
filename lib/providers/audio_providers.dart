import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

final audioPlayerProvider = Provider<AudioPlayer>((ref) {
  final player = AudioPlayer();

  // Setup audio session for playback
  () async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }();

  ref.onDispose(() {
    player.dispose();
  });

  return player;
});

final playingProvider = StreamProvider<bool>((ref) {
  final p = ref.watch(audioPlayerProvider);
  return p.playingStream;
});

final positionProvider = StreamProvider<Duration>((ref) {
  final p = ref.watch(audioPlayerProvider);
  return p.positionStream;
});

final durationProvider = StreamProvider<Duration?>((ref) {
  final p = ref.watch(audioPlayerProvider);
  return p.durationStream;
});

final speedProvider = StreamProvider<double>((ref) {
  final p = ref.watch(audioPlayerProvider);
  return p.speedStream;
});
