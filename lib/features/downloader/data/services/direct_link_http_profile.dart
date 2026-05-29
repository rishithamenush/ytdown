/// Shared browser-like HTTP profile for direct-link probes and downloads.
abstract final class DirectLinkHttpProfile {
  static const userAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  static Map<String, String> headersFor(String url, {String? cookieHeader}) {
    final uri = Uri.tryParse(url);
    final referer = uri != null && uri.host.isNotEmpty
        ? '${uri.scheme}://${uri.host}/'
        : null;
    return {
      'User-Agent': userAgent,
      'Accept-Encoding': 'identity',
      if (referer != null) 'Referer': referer,
      if (cookieHeader != null && cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
    };
  }
}
