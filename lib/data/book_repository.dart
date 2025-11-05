import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;


class BookRepository {
  final String baseUrl;
  BookRepository({required this.baseUrl});

  /// Load and parse a book.json at the provided absolute `bookJsonUrl`.
  /// Returns a map with basic metadata and resolved tracks per language.
  Future<Map<String, dynamic>> loadBookJson(String bookJsonUrl) async {
  debugPrint('BookRepository: fetching book.json from $bookJsonUrl');
  final res = await http.get(Uri.parse(bookJsonUrl));
    if (res.statusCode != 200) {
      throw Exception('Failed to load book.json');
    }

    final Map<String, dynamic> json = jsonDecode(res.body) as Map<String, dynamic>;

    // Resolve cover if provided relative. Support either 'cover' or 'coverUrl' keys
    String? rawCover;
    if (json.containsKey('cover')) {
      rawCover = json['cover'] as String?;
    } else if (json.containsKey('coverUrl')) {
      rawCover = json['coverUrl'] as String?;
    }

    if (rawCover != null && rawCover.isNotEmpty) {
      // If it's already an absolute URL, keep it. Otherwise resolve relative to the book folder.
      if (rawCover.startsWith('http://') || rawCover.startsWith('https://')) {
        json['coverUrl'] = rawCover;
      } else {
        json['coverUrl'] = _joinPaths(_parentPath(bookJsonUrl), rawCover);
      }
    }

    // Resolve each track's audio/transcript paths to absolute URLs.
    // Supports:
    //  - audio: "path.mp3" (single) -> m['url']
    //  - audio: ["part1.mp3", "part2.mp3"] (multi) -> m['segments']
    //  - transcript: "path.vtt" -> m['transcriptUrl']
    //  - transcript: ["p1.vtt", "p2.vtt"] -> m['transcriptSegments']
    final tracks = <String, List<Map<String, dynamic>>>{};
    final rawTracks = json['tracks'] as Map<String, dynamic>? ?? {};
    rawTracks.forEach((lang, list) {
      final resolved = (list as List<dynamic>).map((t) {
        final m = Map<String, dynamic>.from(t as Map);

        // AUDIO: already-resolved 'url' takes precedence (back-compat)
        String? resolvedAudio = m['url'] as String?;

        final audioValue = m['audio'];
        if (resolvedAudio == null || resolvedAudio.isEmpty) {
          if (audioValue is String) {
            String rawAudio = audioValue.isNotEmpty ? audioValue : (m['file'] as String? ?? '');
            if (rawAudio.isNotEmpty && !rawAudio.startsWith('http://') && !rawAudio.startsWith('https://')) {
              rawAudio = _normalizeRelativePath(rawAudio, lang);
            }
            if (rawAudio.isNotEmpty) {
              resolvedAudio = (rawAudio.startsWith('http://') || rawAudio.startsWith('https://'))
                  ? rawAudio
                  : _joinPaths(_parentPath(bookJsonUrl), rawAudio);
              m['url'] = resolvedAudio;
            }
          } else if (audioValue is List) {
            // Multi-file segments
            final segs = <String>[];
            for (final a in audioValue) {
              if (a is String && a.isNotEmpty) {
                String rel = a;
                if (!rel.startsWith('http://') && !rel.startsWith('https://')) {
                  rel = _normalizeRelativePath(rel, lang);
                }
                final url = (rel.startsWith('http://') || rel.startsWith('https://'))
                    ? rel
                    : _joinPaths(_parentPath(bookJsonUrl), rel);
                segs.add(url);
              }
            }
            if (segs.isNotEmpty) {
              m['segments'] = segs;
            }
          } else {
            // Back-compat: use 'file' if present
            String rawAudio = m['file'] as String? ?? '';
            if (rawAudio.isNotEmpty && !rawAudio.startsWith('http://') && !rawAudio.startsWith('https://')) {
              rawAudio = _normalizeRelativePath(rawAudio, lang);
            }
            if (rawAudio.isNotEmpty) {
              resolvedAudio = (rawAudio.startsWith('http://') || rawAudio.startsWith('https://'))
                  ? rawAudio
                  : _joinPaths(_parentPath(bookJsonUrl), rawAudio);
              m['url'] = resolvedAudio;
            }
          }
        } else {
          // Ensure normalized 'url' is set if found
          m['url'] = resolvedAudio;
        }

        // TRANSCRIPT: resolve single or multi
        final trValue = m['transcript'];
        if (trValue is String) {
          if (trValue.isNotEmpty) {
            String rel = trValue;
            if (!rel.startsWith('http://') && !rel.startsWith('https://')) {
              rel = _normalizeRelativePath(rel, lang);
            }
            final transcriptUrl = (rel.startsWith('http://') || rel.startsWith('https://'))
                ? rel
                : _joinPaths(_parentPath(bookJsonUrl), rel);
            m['transcriptUrl'] = transcriptUrl;
          }
        } else if (trValue is List) {
          final tSegs = <String>[];
          for (final tr in trValue) {
            if (tr is String && tr.isNotEmpty) {
              String rel = tr;
              if (!rel.startsWith('http://') && !rel.startsWith('https://')) {
                rel = _normalizeRelativePath(rel, lang);
              }
              final url = (rel.startsWith('http://') || rel.startsWith('https://'))
                  ? rel
                  : _joinPaths(_parentPath(bookJsonUrl), rel);
              tSegs.add(url);
            }
          }
          if (tSegs.isNotEmpty) {
            m['transcriptSegments'] = tSegs;
          }
        }

        // Log summary
        if (m.containsKey('segments')) {
          final count = (m['segments'] as List).length;
          debugPrint('BookRepository: resolved track for lang=$lang -> $count segment(s)');
        } else {
          debugPrint('BookRepository: resolved track for lang=$lang -> ${m['url']}');
        }
        return m;
      }).toList();

      tracks[lang] = resolved;
    });

    json['resolvedTracks'] = tracks;
    return json;
  }

  String _parentPath(String url) {
    final idx = url.lastIndexOf('/');
    if (idx == -1) return url;
    return url.substring(0, idx + 1);
  }

  String _joinPaths(String a, String b) {
    if (a.endsWith('/') && b.startsWith('/')) return a + b.substring(1);
    if (!a.endsWith('/') && !b.startsWith('/')) return '$a/$b';
    return a + b;
  }

  // Normalize relative paths to expected structure:
  //  - If already starts with '<lang>/', leave as-is
  //  - If starts with 'audio/<lang>/' => '<lang>/audio/...'
  //  - If starts with 'transcript/<lang>/' => '<lang>/transcript/...'
  //  - If starts with 'audio/' => '<lang>/audio/...'
  //  - If starts with 'transcript/' => '<lang>/transcript/...'
  // Otherwise, return unchanged
  String _normalizeRelativePath(String path, String lang) {
    if (path.startsWith('$lang/')) return path;
    if (path.startsWith('audio/$lang/')) {
      return path.replaceFirst('audio/$lang/', '$lang/audio/');
    }
    if (path.startsWith('transcript/$lang/')) {
      return path.replaceFirst('transcript/$lang/', '$lang/transcript/');
    }
    if (path.startsWith('audio/')) {
      return '$lang/$path';
    }
    if (path.startsWith('transcript/')) {
      return '$lang/$path';
    }
    return path;
  }
}
