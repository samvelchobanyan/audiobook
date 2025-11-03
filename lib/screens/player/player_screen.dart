import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/catalog_providers.dart';
import '../../providers/audio_providers.dart';
import '../../widgets/player_controls.dart';
import '../../utils/duration_format.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final String bookId;
  const PlayerScreen({required this.bookId, super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  ConcatenatingAudioSource? _source;
  String? coverUrl;
  String? displayTitle;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final book = await ref.read(bookByIdProvider(widget.bookId));
    if (book == null) return;
    // Load book.json and tracks
    final bookRepo = ref.read(bookRepositoryProvider);
    try {
      final raw = await bookRepo.loadBookJson(book.bookJsonUrl);
      // Store resolved cover/title for the UI
      final resolvedCover = raw['coverUrl'] as String?;
      final resolvedTitle = (raw['title'] as String?) ?? book.title;
      // Fallback: if book.json doesn't include a cover, use the catalog cover
      final finalCover = resolvedCover ?? book.coverUrl;
      if (mounted) {
        setState(() {
          coverUrl = finalCover;
          displayTitle = resolvedTitle;
        });
      }
      final lang = (raw['languages'] as List<dynamic>?)?.first as String? ?? 'en';
      final resolved = raw['resolvedTracks'] as Map<String, dynamic>? ?? {};
      final list = (resolved[lang] as List<dynamic>?) ?? [];

      final player = ref.read(audioPlayerProvider);

      if (list.length == 1) {
        final url = list[0]['url'] as String;
        debugPrint('PlayerScreen: loading single track $url');
        final uri = Uri.parse(url);
        await player.setAudioSource(AudioSource.uri(uri, tag: MediaItem(id: widget.bookId, album: raw['title'] ?? '', title: raw['title'] ?? '', artUri: raw['coverUrl'] != null ? Uri.parse(raw['coverUrl'] as String) : null)));
      } else {
        for (final t in list) {
          debugPrint('PlayerScreen: adding track ${t['id']} -> ${t['url']}');
        }
        final children = list.map((t) => AudioSource.uri(Uri.parse(t['url'] as String), tag: MediaItem(id: t['id'] as String? ?? '', album: raw['title'] ?? '', title: t['id'] as String? ?? '', artUri: raw['coverUrl'] != null ? Uri.parse(raw['coverUrl'] as String) : null))).toList();
        _source = ConcatenatingAudioSource(children: children);
        await player.setAudioSource(_source!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load book')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(audioPlayerProvider);
    final position = ref.watch(positionProvider).value ?? Duration.zero;
    final duration = ref.watch(durationProvider).value ?? Duration.zero;

    return Scaffold(
      appBar: AppBar(title: const Text('Player')),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            SizedBox(
              width: 220,
              height: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: coverUrl != null
                    ? CachedNetworkImage(
                        imageUrl: coverUrl!,
                        fit: BoxFit.cover,
                        placeholder: (c, s) => Container(color: Colors.grey[300]),
                        errorWidget: (c, s, e) => Container(color: Colors.grey[300]),
                      )
                    : Container(color: Colors.grey[300]),
              ),
            ),
            const SizedBox(height: 16),
            Text(displayTitle ?? 'Title', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Slider(
              value: position.inMilliseconds.toDouble().clamp(0, duration.inMilliseconds.toDouble() == 0 ? 1 : duration.inMilliseconds.toDouble()),
              max: duration.inMilliseconds.toDouble() == 0 ? 1 : duration.inMilliseconds.toDouble(),
              onChanged: (v) async {
                await player.seek(Duration(milliseconds: v.toInt()));
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatDuration(position)),
                  Text('-${formatDuration(duration - position)}'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const PlayerControls(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(onPressed: () => _showSpeedSheet(), icon: const Icon(Icons.speed), label: const Text('Speed')),
                ElevatedButton.icon(onPressed: () => Navigator.of(context).pushNamed('/transcript/${widget.bookId}'), icon: const Icon(Icons.article), label: const Text('Transcript')),
                ElevatedButton.icon(onPressed: () => Navigator.of(context).pushNamed('/summary/${widget.bookId}'), icon: const Icon(Icons.subject), label: const Text('Summary')),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _showSpeedSheet() {
    showModalBottomSheet(
      context: context,
      builder: (c) {
        final player = ref.read(audioPlayerProvider);
        return ListView(
          shrinkWrap: true,
          children: [0.75, 1.0, 1.25, 1.5, 2.0].map((s) {
            return ListTile(
              title: Text('${s}x'),
              onTap: () async {
                await player.setSpeed(s);
                Navigator.of(context).pop();
              },
            );
          }).toList(),
        );
      },
    );
  }
}
