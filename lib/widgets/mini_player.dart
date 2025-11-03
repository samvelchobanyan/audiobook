import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/audio_providers.dart';
import '../utils/duration_format.dart';

class MiniPlayer extends ConsumerWidget {
  final VoidCallback? onTap;
  const MiniPlayer({super.key, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playing = ref.watch(playingProvider);
    final position = ref.watch(positionProvider).value ?? Duration.zero;
    final duration = ref.watch(durationProvider).value ?? Duration.zero;

    final remaining = duration - position;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Row(
          children: [
            Container(width: 44, height: 44, color: Colors.grey[300]),
            const SizedBox(width: 12),
            Expanded(child: Text('Now playing', style: Theme.of(context).textTheme.bodyLarge)),
            Text('-${formatDuration(remaining)}'),
            const SizedBox(width: 12),
            IconButton(
              icon: Icon(playing.when(data: (_) => _ ? Icons.pause : Icons.play_arrow, loading: () => Icons.play_arrow, error: (_, __) => Icons.play_arrow)),
              onPressed: () async {
                final player = ref.read(audioPlayerProvider);
                if (player.playing) {
                  await player.pause();
                } else {
                  await player.play();
                }
              },
            )
          ],
        ),
      ),
    );
  }
}
