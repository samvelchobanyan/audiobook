import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/book.dart';

class CatalogRepository {
  final String baseUrl;
  CatalogRepository({required this.baseUrl});

  Future<List<BookCardItem>> fetchCatalog() async {
    // Build catalog URL defensively to avoid double slashes
  const catalogPath = 'audiobooks/catalog.json';
    final urlString = baseUrl.endsWith('/') ? '$baseUrl$catalogPath' : '$baseUrl/$catalogPath';
    final url = Uri.parse(urlString);
    debugPrint('CatalogRepository: fetching catalog from $urlString');
    final res = await http.get(url);
    if (res.statusCode != 200) {
      final bodySnippet = res.body.length > 200 ? '${res.body.substring(0, 200)}...' : res.body;
      throw Exception('Failed to load catalog: ${res.statusCode} - $bodySnippet');
    }

    final Map<String, dynamic> json = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (json['audiobooks'] as List<dynamic>?) ?? [];

    return items.map((e) => BookCardItem.fromCatalog(e as Map<String, dynamic>, baseUrl)).toList();
  }
}
