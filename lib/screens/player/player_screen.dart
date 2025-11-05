import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../utils/vtt_parser.dart';

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
  // Metadata for each child in the concatenated source to assist transcript sync
  final List<_ChildMeta> _childrenMeta = [];

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _seekAcrossPlaylist(AudioPlayer player, Duration target) async {
    final state = player.sequenceState;
    final sequence = state?.sequence;
    if (sequence == null || sequence.isEmpty) return;

    var acc = Duration.zero;
    for (int i = 0; i < sequence.length; i++) {
      final d = sequence[i].duration ?? Duration.zero;
      if (target < acc + d) {
        final within = target - acc;
        await player.seek(within, index: i);
        return;
      }
      acc += d;
    }

    // If target is beyond total, seek to end of last item
    final lastIndex = sequence.length - 1;
    final lastDur = sequence[lastIndex].duration ?? Duration.zero;
    await player.seek(lastDur, index: lastIndex);
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

      // Log a consolidated list of playable URLs when opening the player
      debugPrint('PlayerScreen: language=$lang, tracks=${list.length}');
      for (int i = 0; i < list.length; i++) {
        final t = list[i] as Map<String, dynamic>;
        final tTitle = (t['title'] as String?) ?? (t['id'] as String? ?? '');
        final tUrl = t['url'];
        final tTranscript = t['transcriptUrl'];
        debugPrint('PlayerScreen: [$i] title="$tTitle" url=$tUrl transcript=${tTranscript ?? '-'}');
      }

      final player = ref.read(audioPlayerProvider);

      // Build a single concatenated source from tracks and optional segments
      final List<AudioSource> children = [];
      _childrenMeta.clear();
      for (int ti = 0; ti < list.length; ti++) {
        final t = list[ti] as Map<String, dynamic>;
        final id = (t['id'] as String?) ?? 't$ti';
        final title = (t['title'] as String?) ?? id;
        final art = raw['coverUrl'] != null ? Uri.parse(raw['coverUrl'] as String) : null;
        final trackTranscriptUrl = t['transcriptUrl'] as String?;
        final transcriptSegments = (t['transcriptSegments'] as List?)?.cast<String>();

        final segs = t['segments'];
        if (segs is List && segs.isNotEmpty) {
          final trackDurSeconds = (t['duration'] as num?)?.toInt();
          final perSegDuration = (trackDurSeconds != null && trackDurSeconds > 0) ? Duration(seconds: (trackDurSeconds / segs.length).floor()) : null;
          for (int si = 0; si < segs.length; si++) {
            final segUrl = segs[si] as String;
            debugPrint('PlayerScreen: adding segment $id#${si + 1} -> $segUrl');
            final transcriptForSeg = (transcriptSegments != null && si < transcriptSegments.length) ? transcriptSegments[si] : trackTranscriptUrl;
            children.add(
              AudioSource.uri(
                Uri.parse(segUrl),
                tag: MediaItem(
                  id: '${id}_$si',
                  album: raw['title'] ?? '',
                  title: title,
                  duration: perSegDuration,
                  artUri: art,
                ),
              ),
            );
            _childrenMeta.add(_ChildMeta(
              logicalTrackId: id,
              title: title,
              transcriptUrl: transcriptForSeg,
              segmentIndex: si,
              estimatedDuration: perSegDuration,
            ));
          }
        } else {
          final url = t['url'] as String;
          debugPrint('PlayerScreen: adding track $id -> $url');
          children.add(
            AudioSource.uri(
              Uri.parse(url),
              tag: MediaItem(
                id: id,
                album: raw['title'] ?? '',
                title: title,
                duration: (t['duration'] is num) ? Duration(seconds: (t['duration'] as num).toInt()) : null,
                artUri: art,
              ),
            ),
          );
          _childrenMeta.add(_ChildMeta(
            logicalTrackId: id,
            title: title,
            transcriptUrl: trackTranscriptUrl,
            segmentIndex: null,
            estimatedDuration: (t['duration'] is num) ? Duration(seconds: (t['duration'] as num).toInt()) : null,
          ));
        }
      }

      _source = ConcatenatingAudioSource(children: children);
      await player.setAudioSource(_source!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load book')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(audioPlayerProvider);
    final combined = ref.watch(combinedProgressProvider).value;
    final position = combined?.position ?? Duration.zero;
    final duration = combined?.total ?? Duration.zero;
    final timelineReady = duration.inMilliseconds > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Player'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Prefer going back if possible; otherwise, navigate to home
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
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
              value: timelineReady ? position.inMilliseconds.toDouble().clamp(0, duration.inMilliseconds.toDouble()) : 0,
              max: timelineReady ? duration.inMilliseconds.toDouble() : 1,
              onChanged: (v) async {
                if (!timelineReady) return;
                final target = Duration(milliseconds: v.toInt());
                await _seekAcrossPlaylist(player, target);
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatDuration(timelineReady ? position : Duration.zero)),
                  Text('-${formatDuration(timelineReady ? (duration - position) : Duration.zero)}'),
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
                ElevatedButton.icon(onPressed: _showTranscriptSheet, icon: const Icon(Icons.article), label: const Text('Transcript')),
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

  void _showTranscriptSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (c) {
        return _TranscriptSheet(childrenMeta: _childrenMeta);
      },
    );
  }
}

class _ChildMeta {
  final String logicalTrackId;
  final String title;
  final String? transcriptUrl; // if null, no transcript
  final int? segmentIndex; // null for single-file track
  final Duration? estimatedDuration;
  const _ChildMeta({
    required this.logicalTrackId,
    required this.title,
    required this.transcriptUrl,
    required this.segmentIndex,
    required this.estimatedDuration,
  });
}

class _TranscriptSheet extends ConsumerStatefulWidget {
  final List<_ChildMeta> childrenMeta;
  const _TranscriptSheet({required this.childrenMeta});

  @override
  ConsumerState<_TranscriptSheet> createState() => _TranscriptSheetState();
}

class _TranscriptSheetState extends ConsumerState<_TranscriptSheet> {
  List<VttCue>? _cues;
  String? _loadedUrl;

  @override
  void initState() {
    super.initState();
    _maybeLoadCurrentTranscript();
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(audioPlayerProvider);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: StreamBuilder<SequenceState?>(
          stream: player.sequenceStateStream,
          builder: (context, _) {
            _maybeLoadCurrentTranscript();
            return StreamBuilder<Duration>(
              stream: player.positionStream,
              builder: (context, posSnap) {
                final pos = posSnap.data ?? player.position;
                final idx = player.sequenceState?.currentIndex ?? 0;
                final effectivePos = pos + _segmentOffsetForIndex(idx);
                return _buildBody(effectivePos);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(Duration position) {
    if (_cues == null) {
      return const Center(child: CircularProgressIndicator());
    }
    // Highlight cue containing current position
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _cues!.length,
      itemBuilder: (context, index) {
        final cue = _cues![index];
        final active = position >= cue.start && position < cue.end;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: active ? BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(8)) : null,
          child: Text(cue.text),
        );
      },
    );
  }

  Future<void> _maybeLoadCurrentTranscript() async {
    final player = ref.read(audioPlayerProvider);
    final idx = player.sequenceState?.currentIndex ?? 0;
    if (idx < 0 || idx >= widget.childrenMeta.length) return;
    final meta = widget.childrenMeta[idx];
    final url = meta.transcriptUrl;
    if (url == null || url.isEmpty) {
      if (_cues != null) setState(() => _cues = null);
      return;
    }
    if (_loadedUrl == url && _cues != null) return;
    try {
      final cues = await fetchAndParseVtt(url);
      if (mounted) {
        setState(() {
          _loadedUrl = url;
          _cues = cues;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadedUrl = url;
          _cues = const [];
        });
      }
    }
  }

  Duration _segmentOffsetForIndex(int currentIndex) {
    if (currentIndex <= 0 || currentIndex >= widget.childrenMeta.length) return Duration.zero;
    final current = widget.childrenMeta[currentIndex];
    // Only apply offset for segmented tracks sharing the same transcript file
    if (current.segmentIndex == null || current.transcriptUrl == null) {
      return Duration.zero;
    }
    var acc = Duration.zero;
    for (int i = 0; i < currentIndex; i++) {
      final m = widget.childrenMeta[i];
      if (m.logicalTrackId == current.logicalTrackId && m.transcriptUrl == current.transcriptUrl) {
        acc += m.estimatedDuration ?? Duration.zero;
      }
    }
    return acc;
  }
}
