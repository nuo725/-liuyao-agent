import 'dart:convert';

import 'package:http/http.dart' as http;

abstract class WebSearchService {
  Future<List<String>> search({required String query, int maxResults = 5});
}

/// Google Programmable Search JSON API
/// Required dart defines:
/// - GOOGLE_SEARCH_API_KEY
/// - GOOGLE_SEARCH_CX
class GoogleWebSearchServiceImpl implements WebSearchService {
  static const String _apiKey = String.fromEnvironment(
    'GOOGLE_SEARCH_API_KEY',
    defaultValue: '',
  );
  static const String _cx = String.fromEnvironment(
    'GOOGLE_SEARCH_CX',
    defaultValue: '',
  );

  @override
  Future<List<String>> search({
    required String query,
    int maxResults = 5,
  }) async {
    final q = query.trim();
    if (q.isEmpty || _apiKey.isEmpty || _cx.isEmpty) {
      return const [];
    }

    final uri = Uri.https('www.googleapis.com', '/customsearch/v1', {
      'key': _apiKey,
      'cx': _cx,
      'q': q,
      'num': maxResults.clamp(1, 10).toString(),
      'hl': 'zh-CN',
      'safe': 'active',
    });

    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) return const [];

      final data = jsonDecode(resp.body);
      final items = (data is Map<String, dynamic> ? data['items'] : null);
      if (items is! List) return const [];

      final out = <String>[];
      for (final item in items) {
        if (item is! Map) continue;
        final title = (item['title'] ?? '').toString().trim();
        final snippet = (item['snippet'] ?? '').toString().trim();
        final link = (item['link'] ?? '').toString().trim();
        final line = [title, snippet, link]
            .where((e) => e.isNotEmpty)
            .join(' | ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (line.isNotEmpty) out.add(line);
      }
      return out.take(maxResults).toList();
    } catch (_) {
      return const [];
    }
  }
}

final webSearchServiceProvider = GoogleWebSearchServiceImpl();
