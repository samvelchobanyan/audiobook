
class BookCardItem {
  final String id;
  final String title;
  final String author;
  final String coverUrl;
  final String bookJsonUrl;
  final List<String> languages;

  BookCardItem({
    required this.id,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.bookJsonUrl,
    required this.languages,
  });

  factory BookCardItem.fromCatalog(Map<String, dynamic> json, String baseUrl) {
    final id = json['id'] as String? ?? '';
    final title = json['title'] as String? ?? '';
    final author = json['author'] as String? ?? '';
    final cover = json['cover'] as String? ?? '';
    final bookJson = json['bookJson'] as String? ?? '';
    final languages = (json['languages'] as List<dynamic>?)?.map((e) => e as String).toList() ?? ['en'];

    return BookCardItem(
      id: id,
      title: title,
      author: author,
      coverUrl: '$baseUrl$cover',
      bookJsonUrl: '$baseUrl$bookJson',
      languages: languages,
    );
  }
}

class TrackItem {
  final String id;
  final String url;
  final Duration? duration;

  TrackItem({required this.id, required this.url, this.duration});

  factory TrackItem.fromJson(Map<String, dynamic> json, String baseTrackUrl) {
    final id = json['id'] as String? ?? '';
    final durationSeconds = json['duration'] as num?;

    // If the repository already resolved a full 'url', prefer it.
    if (json.containsKey('url')) {
      final resolved = json['url'] as String? ?? '';
      return TrackItem(
        id: id,
        url: resolved,
        duration: durationSeconds != null ? Duration(seconds: durationSeconds.toInt()) : null,
      );
    }

    // Otherwise resolve from baseTrackUrl (which should be the parent folder or bookJsonUrl).
    final file = json['file'] as String? ?? '';
    final candidate = '$baseTrackUrl/$file'.replaceAll('//', '/');
    return TrackItem(
      id: id,
      url: candidate,
      duration: durationSeconds != null ? Duration(seconds: durationSeconds.toInt()) : null,
    );
  }
}
