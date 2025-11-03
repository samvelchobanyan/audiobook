import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../providers/audio_providers.dart';

class PlayerControls extends ConsumerWidget {
  const PlayerControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(audioPlayerProvider);
    final playing = ref.watch(playingProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          iconSize: 36,
          onPressed: () async {
            final pos = await player.positionStream.first;
            await player.seek(pos - const Duration(seconds: 15));
          },
          icon: const Icon(Icons.replay_10),
        ),
        const SizedBox(width: 12),
        IconButton(
          iconSize: 56,
          onPressed: () async {
            if (player.playing) {
              await player.pause();
            } else {
              await player.play();
            }
          },
          icon: playing.when(data: (_) => Icon(player.playing ? Icons.pause_circle_filled : Icons.play_circle_filled), loading: () => const Icon(Icons.play_circle_filled), error: (_, __) => const Icon(Icons.play_circle_filled)),
        ),
        const SizedBox(width: 12),
        IconButton(
          iconSize: 36,
          onPressed: () async {
            final pos = await player.positionStream.first;
            await player.seek(pos + const Duration(seconds: 15));
          },
          icon: const Icon(Icons.forward_10),
        ),
      ],
    );
  }
}
