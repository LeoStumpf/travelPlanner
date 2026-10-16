import 'package:http/http.dart' as http;

class LinkPreview {
  final String? title;
  final String? imageUrl;
  const LinkPreview(this.title, this.imageUrl);
}

/// Fetches og:title / og:image (falls back to <title>).
Future<LinkPreview> fetchLinkPreview(String url, {http.Client? client}) async {
  final c = client ?? http.Client();
  final uri = Uri.parse(url);
  final res = await c.get(uri, headers: {
    'User-Agent': 'Mozilla/5.0 (Linux; Android 14) TravelPlanner/1.0',
  }).timeout(const Duration(seconds: 10));
  if (res.statusCode >= 400) return const LinkPreview(null, null);
  return parseLinkPreview(res.body, uri);
}

LinkPreview parseLinkPreview(String html, Uri base) {
  String? meta(String prop) {
    final patterns = [
      RegExp('<meta[^>]+(?:property|name)=["\']$prop["\'][^>]*content=["\']([^"\']*)["\']', caseSensitive: false),
      RegExp('<meta[^>]+content=["\']([^"\']*)["\'][^>]*(?:property|name)=["\']$prop["\']', caseSensitive: false),
    ];
    for (final r in patterns) {
      final m = r.firstMatch(html);
      if (m != null && m.group(1)!.trim().isNotEmpty) return _unescape(m.group(1)!.trim());
    }
    return null;
  }

  var title = meta('og:title') ?? meta('twitter:title');
  title ??= RegExp(r'<title[^>]*>([^<]*)</title>', caseSensitive: false).firstMatch(html)?.group(1)?.trim();
  var image = meta('og:image') ?? meta('twitter:image');
  if (image != null) image = base.resolve(image).toString();
  return LinkPreview(title == null || title.isEmpty ? null : _unescape(title), image);
}

String _unescape(String s) => s
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&#x27;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>');
