import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';

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

class CombinedProgress {
  final Duration position; // position across entire playlist
  final Duration total; // total duration across entire playlist
  CombinedProgress(this.position, this.total);
}

// Emits total duration across the whole sequence and a virtual position that
// adds current item position to the sum of all previous item durations.
final combinedProgressProvider = StreamProvider<CombinedProgress>((ref) {
  final p = ref.watch(audioPlayerProvider);

  late final StreamController<CombinedProgress> controller;
  StreamSubscription<Duration>? posSub;
  StreamSubscription<SequenceState?>? seqSub;
  StreamSubscription<Duration?>? durSub;

  List<Duration?> itemDurations = const [];
  int currentIndex = 0;
  Duration currentPos = Duration.zero;

  Duration totalDuration() {
    var sum = Duration.zero;
    for (final d in itemDurations) {
      if (d != null) sum += d;
    }
    return sum;
  }

  Duration virtualPosition() {
    var sum = Duration.zero;
    for (int i = 0; i < currentIndex && i < itemDurations.length; i++) {
      final d = itemDurations[i];
      if (d != null) sum += d;
    }
    return sum + currentPos;
  }

  void emit() {
    controller.add(CombinedProgress(virtualPosition(), totalDuration()));
  }

  controller = StreamController<CombinedProgress>(onListen: () {
    // Sequence changes: update durations and current index
    seqSub = p.sequenceStateStream.listen((seq) {
      currentIndex = seq?.currentIndex ?? 0;
      final list = seq?.sequence ?? const <IndexedAudioSource>[];
      itemDurations = list.map((s) {
        final d = s.duration;
        if (d != null) return d;
        // Try to read duration from tag (MediaItem) if provided
        try {
          final tag = s.tag;
          final dur = (tag as dynamic).duration as Duration?;
          return dur;
        } catch (_) {
          return null;
        }
      }).toList();
      emit();
    });
    // Position within current item
    posSub = p.positionStream.listen((pos) {
      currentPos = pos;
      emit();
    });
    // As items get prepared, their duration changes
    durSub = p.durationStream.listen((_) {
      // durationStream is current item only; rely on sequenceState to refresh too
      // Emit anyway to nudge the UI
      emit();
    });
  }, onPause: () {
    posSub?.pause();
    seqSub?.pause();
    durSub?.pause();
  }, onResume: () {
    posSub?.resume();
    seqSub?.resume();
    durSub?.resume();
  }, onCancel: () async {
    await posSub?.cancel();
    await seqSub?.cancel();
    await durSub?.cancel();
  });

  ref.onDispose(() async {
    await controller.close();
  });

  return controller.stream;
});
