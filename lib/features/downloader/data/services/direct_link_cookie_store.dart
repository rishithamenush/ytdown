/// In-memory Cloudflare / session cookies keyed by host (e.g. file-examples.com).
class DirectLinkCookieStore {
  final Map<String, String> _cookieHeaders = {};

  String? cookieHeaderForHost(String host) => _cookieHeaders[host];

  bool hasSession(String host) {
    final c = _cookieHeaders[host];
    return c != null && c.isNotEmpty;
  }

  void save(String host, String cookieHeader) {
    if (host.isEmpty || cookieHeader.isEmpty) return;
    _cookieHeaders[host] = cookieHeader;
  }

  void clear(String host) => _cookieHeaders.remove(host);
}
