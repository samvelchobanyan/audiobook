import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/book.dart';
import '../data/catalog_repository.dart';
import '../data/book_repository.dart';

// Base origin for S3 — keep trailing slash for simpler joins (repositories normalize paths)
final baseUrlProvider = Provider<String>((ref) => 'https://samo-audiobooks-test.s3.eu-north-1.amazonaws.com/');

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  final base = ref.watch(baseUrlProvider);
  return CatalogRepository(baseUrl: base);
});

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  final base = ref.watch(baseUrlProvider);
  return BookRepository(baseUrl: base);
});

final booksProvider = FutureProvider<List<BookCardItem>>((ref) async {
  final repo = ref.read(catalogRepositoryProvider);
  final base = ref.read(baseUrlProvider);
  final catalogPath = 'audiobooks/catalog.json';
  final catalogUrl = base.endsWith('/') ? '${base}$catalogPath' : '$base/$catalogPath';
  // Log the exact URL the app will fetch so it appears in the console
  // Visible in Flutter logs (debugPrint)
  // Example: Catalog URL: https://.../catalog.json
  // ignore: avoid_print
  print('Catalog URL: $catalogUrl');
  return repo.fetchCatalog();
});

final bookByIdProvider = Provider.family<Future<BookCardItem?>, String>((ref, id) async {
  final list = await ref.read(booksProvider.future);
  try {
    return list.firstWhere((b) => b.id == id);
  } catch (_) {
    return null;
  }
});

final tracksProvider = FutureProvider.family<List<TrackItem>, Map<String, String>>((ref, params) async {
  // params: {'bookJsonUrl': ..., 'lang': 'en'}
  final bookRepo = ref.read(bookRepositoryProvider);
  final bookJsonUrl = params['bookJsonUrl']!;
  final lang = params['lang']!;

  final raw = await bookRepo.loadBookJson(bookJsonUrl);
  final resolved = raw['resolvedTracks'] as Map<String, dynamic>? ?? {};
  final list = (resolved[lang] as List<dynamic>?) ?? [];

  return list.map((t) => TrackItem.fromJson(Map<String, dynamic>.from(t as Map), bookJsonUrl)).toList();
});
