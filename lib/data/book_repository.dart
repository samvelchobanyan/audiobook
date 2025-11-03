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

    // Resolve each track file to absolute URL
    final tracks = <String, List<Map<String, dynamic>>>{};
    final rawTracks = json['tracks'] as Map<String, dynamic>? ?? {};
    rawTracks.forEach((lang, list) {
      final resolved = (list as List<dynamic>).map((t) {
        final m = Map<String, dynamic>.from(t as Map);
        final file = m['file'] as String? ?? '';
        m['url'] = _joinPaths(_parentPath(bookJsonUrl), file);
        debugPrint('BookRepository: resolved track for lang=$lang -> ${m['url']}');
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
}
