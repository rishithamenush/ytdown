import 'package:dio/dio.dart';

class FacebookRemoteDataSource {
  FacebookRemoteDataSource({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                followRedirects: true,
                maxRedirects: 5,
                receiveTimeout: const Duration(seconds: 30),
                sendTimeout: const Duration(seconds: 30),
              ),
            );

  final Dio _dio;

  // Cache last successful result to avoid re-fetching the same URL.
  String? _cachedUrl;
  FacebookVideoData? _cachedData;

  static const _desktopUa =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
  static const _mobileUa =
      'Mozilla/5.0 (Linux; Android 13; SM-S908B) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';
  static const _crawlerUa = 'facebookexternalhit/1.1';

  Future<FacebookVideoData> getVideo(String url) async {
    final trimmed = url.trim();
    if (_cachedUrl == trimmed && _cachedData != null) {
      return _cachedData!;
    }
    final candidates = await _buildCandidateUrls(trimmed);
    FacebookVideoData? bestAcrossCandidates;
    Object? lastError;

    for (final candidate in candidates) {
      final attempts = <Future<FacebookVideoData?> Function()>[
        () => _tryCrawler(candidate),
        () => _tryFdown(candidate),
        () => _tryFbdown(candidate),
        () => _trySnapsave(candidate),
        () => _tryEmbed(candidate),
        () => _tryMbasic(candidate),
        () => _tryDesktop(candidate),
      ];

      FacebookVideoData? bestForCandidate;
      for (final attempt in attempts) {
        try {
          final result = await attempt();
          if (result == null) continue;
          if (result.hdUrl != null || result.sdUrl != null) {
            if (result.hdUrl != null) {
              _cachedUrl = trimmed;
              _cachedData = result;
              return result;
            }
            bestForCandidate ??= result;
          }
        } catch (e) {
          lastError = e;
        }
      }

      bestAcrossCandidates ??= bestForCandidate;
    }

    if (bestAcrossCandidates != null) {
      _cachedUrl = trimmed;
      _cachedData = bestAcrossCandidates;
      return bestAcrossCandidates;
    }

    throw StateError(_userFacingError(lastError));
  }

  String _userFacingError(Object? lastError) {
    const base = 'Could not download this Facebook video. ';
    // Network-level: ISP / DNS / offline. Suggest a network check rather
    // than implying the video itself is unavailable.
    final s = lastError?.toString() ?? '';
    if (s.contains('Failed host lookup') ||
        s.contains('SocketException') ||
        s.contains('Connection refused') ||
        s.contains('Network is unreachable')) {
      return '${base}Network is blocking the download services. '
          'Try a different Wi-Fi or mobile data connection.';
    }
    return '${base}It may be private, deleted, or require login to view.';
  }

  Future<FacebookVideoData?> _tryFdown(String originalUrl) async {
    final response = await _dio.post<String>(
      'https://fdown.net/download.php',
      options: Options(
        responseType: ResponseType.plain,
        contentType: 'application/x-www-form-urlencoded',
        followRedirects: true,
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          'User-Agent': _desktopUa,
          'Origin': 'https://fdown.net',
          'Referer': 'https://fdown.net/',
          'Accept': 'text/html,application/xhtml+xml',
          'Accept-Language': 'en-US,en;q=0.9',
        },
        validateStatus: (s) => s != null && s < 500,
      ),
      data: {'URLz': originalUrl},
    );

    final html = response.data;
    if (html == null || html.isEmpty) return null;

    final hd = _matchAnchorById(html, 'hdlink');
    final sd = _matchAnchorById(html, 'sdlink');

    final hdOk = hd != null && hd.startsWith('http');
    final sdOk = sd != null && sd.startsWith('http');
    if (!hdOk && !sdOk) return null;

    return FacebookVideoData(
      id: _extractVideoId(originalUrl) ?? _hashId(originalUrl),
      title: _extractMeta(html, 'og:title') ?? 'Facebook video',
      author: _extractAuthor(html) ?? 'Facebook',
      thumbnailUrl: _extractMeta(html, 'og:image') ?? '',
      hdUrl: hdOk ? hd : null,
      sdUrl: sdOk ? sd : null,
      sourceUrl: originalUrl,
    );
  }

  Future<FacebookVideoData?> _tryCrawler(String originalUrl) async {
    final html = await _fetchHtml(originalUrl, ua: _crawlerUa);

    final fromJson = _parseFromHtml(
      html: html,
      sourceUrl: originalUrl,
      fallbackTitle: 'Facebook video',
    );
    if (fromJson != null &&
        (fromJson.hdUrl != null || fromJson.sdUrl != null)) {
      return fromJson;
    }

    final og = _extractMeta(html, 'og:video') ??
        _extractMeta(html, 'og:video:secure_url') ??
        _extractMeta(html, 'og:video:url');
    if (og == null || og.isEmpty || !og.startsWith('http')) return null;

    return FacebookVideoData(
      id: _extractVideoId(originalUrl) ?? _hashId(originalUrl),
      title: _extractMeta(html, 'og:title') ?? 'Facebook video',
      author: _extractAuthor(html) ?? 'Facebook',
      thumbnailUrl: _extractMeta(html, 'og:image') ?? '',
      hdUrl: og,
      sdUrl: null,
      sourceUrl: originalUrl,
    );
  }

  Future<FacebookVideoData?> _tryFbdown(String originalUrl) async {
    final response = await _dio.post<String>(
      'https://fbdown.net/download.php',
      options: Options(
        responseType: ResponseType.plain,
        contentType: 'application/x-www-form-urlencoded',
        followRedirects: true,
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          'User-Agent': _desktopUa,
          'Origin': 'https://fbdown.net',
          'Referer': 'https://fbdown.net/',
          'Accept': 'text/html,application/xhtml+xml',
          'Accept-Language': 'en-US,en;q=0.9',
        },
        validateStatus: (s) => s != null && s < 500,
      ),
      data: {'URLz': originalUrl},
    );

    final html = response.data;
    if (html == null || html.isEmpty) return null;

    final hd = _matchAnchorById(html, 'hdlink');
    final sd = _matchAnchorById(html, 'sdlink');

    final hdOk = hd != null && hd.startsWith('http');
    final sdOk = sd != null && sd.startsWith('http');
    if (!hdOk && !sdOk) return null;

    return FacebookVideoData(
      id: _extractVideoId(originalUrl) ?? _hashId(originalUrl),
      title: _extractMeta(html, 'og:title') ?? 'Facebook video',
      author: _extractAuthor(html) ?? 'Facebook',
      thumbnailUrl: _extractMeta(html, 'og:image') ?? '',
      hdUrl: hdOk ? hd : null,
      sdUrl: sdOk ? sd : null,
      sourceUrl: originalUrl,
    );
  }

  Future<FacebookVideoData?> _trySnapsave(String originalUrl) async {
    final response = await _dio.post<String>(
      'https://snapsave.app/action.php?lang=en',
      options: Options(
        responseType: ResponseType.plain,
        contentType: 'application/x-www-form-urlencoded',
        followRedirects: true,
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          'User-Agent': _desktopUa,
          'Origin': 'https://snapsave.app',
          'Referer': 'https://snapsave.app/',
          'Accept': '*/*',
          'Accept-Language': 'en-US,en;q=0.9',
          'X-Requested-With': 'XMLHttpRequest',
        },
        validateStatus: (s) => s != null && s < 500,
      ),
      data: {'url': originalUrl},
    );

    final body = response.data;
    if (body == null || body.isEmpty) return null;

    var html = body;
    final jsonMatch =
        RegExp(r'"data"\s*:\s*"([\s\S]*?)"\s*[},]').firstMatch(body);
    if (jsonMatch != null) {
      html = _decodeJsString(jsonMatch.group(1) ?? '');
    }

    final hd = _matchAnchorByLabel(
          html,
          RegExp(r'Download\s*HD|HD\s*Quality|render-?\s*hd',
              caseSensitive: false),
        ) ??
        _matchAnchorById(html, 'hdlink');
    final sd = _matchAnchorByLabel(
          html,
          RegExp(r'Download\s*SD|SD\s*Quality|render-?\s*sd|Download\s*Video',
              caseSensitive: false),
        ) ??
        _matchAnchorById(html, 'sdlink');

    final hdOk = hd != null && hd.startsWith('http');
    final sdOk = sd != null && sd.startsWith('http') && hd != sd;
    if (!hdOk && !sdOk) return null;

    return FacebookVideoData(
      id: _extractVideoId(originalUrl) ?? _hashId(originalUrl),
      title: _extractMeta(html, 'og:title') ?? 'Facebook video',
      author: _extractAuthor(html) ?? 'Facebook',
      thumbnailUrl: _extractMeta(html, 'og:image') ?? '',
      hdUrl: hdOk ? hd : null,
      sdUrl: sdOk ? sd : null,
      sourceUrl: originalUrl,
    );
  }

  /// Finds `<a id="[id]">` regardless of attribute order and decodes HTML entities.
  String? _matchAnchorById(String html, String id) {
    final pattern = RegExp(
      '''<a\\b([^>]*?)>''',
      caseSensitive: false,
    );
    for (final m in pattern.allMatches(html)) {
      final attrs = m.group(1) ?? '';
      if (!RegExp('''\\bid\\s*=\\s*["']$id["']''',
              caseSensitive: false)
          .hasMatch(attrs)) {
        continue;
      }
      final hrefMatch = RegExp(
        '''\\bhref\\s*=\\s*["']([^"']+)["']''',
        caseSensitive: false,
      ).firstMatch(attrs);
      final raw = hrefMatch?.group(1);
      if (raw != null && raw.isNotEmpty) return _decodeHtmlEntities(raw);
    }
    return null;
  }

  /// Finds first anchor whose inner text matches [labelRegex].
  String? _matchAnchorByLabel(String html, RegExp labelRegex) {
    final anchor = RegExp(
      '''<a\\b([^>]*?)>([\\s\\S]*?)</a>''',
      caseSensitive: false,
    );
    for (final m in anchor.allMatches(html)) {
      final attrs = m.group(1) ?? '';
      final text = m.group(2) ?? '';
      if (!labelRegex.hasMatch(text)) continue;
      final hrefMatch = RegExp(
        '''\\bhref\\s*=\\s*["']([^"']+)["']''',
        caseSensitive: false,
      ).firstMatch(attrs);
      final raw = hrefMatch?.group(1);
      if (raw != null && raw.isNotEmpty && raw.startsWith('http')) {
        return _decodeHtmlEntities(raw);
      }
    }
    return null;
  }

  Future<FacebookVideoData?> _tryEmbed(String originalUrl) async {
    final embed = 'https://www.facebook.com/plugins/video.php'
        '?href=${Uri.encodeQueryComponent(originalUrl)}'
        '&show_text=0&width=560';
    final html = await _fetchHtml(embed, ua: _desktopUa);
    return _parseFromHtml(
      html: html,
      sourceUrl: originalUrl,
      fallbackTitle: 'Facebook video',
    );
  }

  Future<FacebookVideoData?> _tryMbasic(String originalUrl) async {
    final mbasic = originalUrl.replaceFirst(
      RegExp(r'https?://(www\.|web\.|m\.)?facebook\.com'),
      'https://mbasic.facebook.com',
    );
    final html = await _fetchHtml(
      mbasic,
      ua: _mobileUa,
      cookies: 'locale=en_US;',
    );

    final sourceMatch = RegExp(
      r'''<source[^>]+src=["']([^"']+\.mp4[^"']*)["']''',
      caseSensitive: false,
    ).firstMatch(html);
    String? mp4 = sourceMatch?.group(1);

    if (mp4 == null) {
      final aMatch = RegExp(
        r'''<a[^>]+href=["']([^"']+\.mp4[^"']*)["']''',
        caseSensitive: false,
      ).firstMatch(html);
      mp4 = aMatch?.group(1);
    }

    if (mp4 == null) {
      return _parseFromHtml(
        html: html,
        sourceUrl: originalUrl,
        fallbackTitle: 'Facebook video',
      );
    }

    return FacebookVideoData(
      id: _extractVideoId(originalUrl) ?? _hashId(originalUrl),
      title: _extractMeta(html, 'og:title') ?? 'Facebook video',
      author: _extractAuthor(html) ?? 'Facebook',
      thumbnailUrl: _extractMeta(html, 'og:image') ?? '',
      hdUrl: mp4,
      sdUrl: null,
      sourceUrl: originalUrl,
    );
  }

  Future<FacebookVideoData?> _tryDesktop(String originalUrl) async {
    final html = await _fetchHtml(originalUrl, ua: _desktopUa);
    return _parseFromHtml(
      html: html,
      sourceUrl: originalUrl,
      fallbackTitle: 'Facebook video',
    );
  }

  FacebookVideoData? _parseFromHtml({
    required String html,
    required String sourceUrl,
    required String fallbackTitle,
  }) {
    final hdUrl = _extractUrl(html, [
      'hd_src_no_ratelimit',
      'hd_src',
      'playable_url_quality_hd',
      'browser_native_hd_url',
    ]);
    final sdUrl = _extractUrl(html, [
      'sd_src_no_ratelimit',
      'sd_src',
      'playable_url',
      'browser_native_sd_url',
    ]);

    String? og;
    if (hdUrl == null && sdUrl == null) {
      og = _extractMeta(html, 'og:video') ??
          _extractMeta(html, 'og:video:url') ??
          _extractMeta(html, 'og:video:secure_url');
    }

    if (hdUrl == null && sdUrl == null && (og == null || og.isEmpty)) {
      return null;
    }

    final dedupedSd = sdUrl == hdUrl ? null : sdUrl;
    return FacebookVideoData(
      id: _extractVideoId(sourceUrl) ?? _hashId(sourceUrl),
      title: _extractMeta(html, 'og:title') ?? fallbackTitle,
      author: _extractAuthor(html) ?? 'Facebook',
      thumbnailUrl: _extractMeta(html, 'og:image') ?? '',
      hdUrl: hdUrl ?? og,
      sdUrl: dedupedSd,
      sourceUrl: sourceUrl,
    );
  }

  Future<String> _fetchHtml(
    String url, {
    required String ua,
    String? cookies,
  }) async {
    final response = await _dio.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        headers: {
          'User-Agent': ua,
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
          if (cookies != null) 'Cookie': cookies,
          // Facebook serves an empty-ish response without these in some
          // regions / IP ranges.
          'sec-ch-ua':
              '"Not_A Brand";v="8", "Chromium";v="120", "Google Chrome";v="120"',
          'sec-ch-ua-mobile': ua == _mobileUa ? '?1' : '?0',
          'sec-ch-ua-platform': '"Windows"',
          'Upgrade-Insecure-Requests': '1',
        },
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    final body = response.data;
    if (body == null || body.isEmpty) {
      throw StateError('Facebook returned an empty response');
    }
    return body;
  }

  String? _extractUrl(String html, List<String> keys) {
    for (final key in keys) {
      // Match unicode-escaped colons too (`"hd_src":"https:\/\/..."`) which
      // is what the inline JSON ships.
      final pattern = RegExp('"$key"\\s*:\\s*"([^"]+)"');
      for (final match in pattern.allMatches(html)) {
        final raw = match.group(1);
        if (raw == null || raw.isEmpty) continue;
        final decoded = _decodeJsString(raw);
        if (decoded.startsWith('http')) return decoded;
      }
    }
    return null;
  }

  String? _extractMeta(String html, String property) {
    final patterns = [
      RegExp(
        '<meta[^>]+property=["\']${RegExp.escape(property)}["\']'
        '[^>]*content=["\']([^"\']+)["\']',
        caseSensitive: false,
      ),
      RegExp(
        '<meta[^>]+content=["\']([^"\']+)["\']'
        '[^>]*property=["\']${RegExp.escape(property)}["\']',
        caseSensitive: false,
      ),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(html);
      if (m != null) {
        final raw = m.group(1);
        if (raw != null && raw.isNotEmpty) {
          return _decodeHtmlEntities(raw);
        }
      }
    }
    return null;
  }

  String? _extractAuthor(String html) {
    final keys = ['ownerName', 'owner_name', 'page_name', 'actor_name'];
    for (final key in keys) {
      final m = RegExp('"$key":"([^"]+)"').firstMatch(html);
      if (m != null) {
        final raw = m.group(1);
        if (raw != null && raw.isNotEmpty) return _decodeJsString(raw);
      }
    }
    return _extractMeta(html, 'og:site_name');
  }

  String _decodeJsString(String raw) {
    var s = raw.replaceAll(r'\/', '/');
    s = s.replaceAllMapped(
      RegExp(r'\\u([0-9a-fA-F]{4})'),
      (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
    );
    s = s.replaceAll(r'\"', '"').replaceAll(r'\\', r'\');
    return s;
  }

  String _decodeHtmlEntities(String s) {
    return s
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }

  Future<String> _normalizeUrl(String url) async {
    var u = url;
    if (u.startsWith('//')) u = 'https:$u';
    if (!u.startsWith('http')) u = 'https://$u';
    u = u.replaceFirst(
      RegExp(r'^https?://fb\.com'),
      'https://www.facebook.com',
    );
    u = _canonicalizeFacebookUrl(u);

    // Facebook share links (`/share/r/...`, `/share/v/...`) are redirect stubs.
    // Resolve them first so downstream strategies see a canonical video URL
    // like `/reel/<id>` or `/watch/?v=<id>`.
    try {
      final uri = Uri.parse(u);
      final host = uri.host.toLowerCase();
      final path = uri.path.toLowerCase();
      final isFacebookHost = host == 'facebook.com' ||
          host == 'www.facebook.com' ||
          host == 'm.facebook.com' ||
          host == 'web.facebook.com' ||
          host == 'mbasic.facebook.com';
      final isSharePath = path.startsWith('/share/');
      if (isFacebookHost && isSharePath) {
        final resolved = await _resolveRedirectUrl(u);
        if (resolved != null && resolved.isNotEmpty) {
          return _canonicalizeFacebookUrl(resolved);
        }
      }
    } catch (_) {
      // Keep original URL on parse/resolve failure.
    }
    return _canonicalizeFacebookUrl(u);
  }

  Future<List<String>> _buildCandidateUrls(String input) async {
    final out = <String>[];
    final seen = <String>{};

    Future<void> addUrl(String raw) async {
      final n = await _normalizeUrl(raw);
      if (n.isNotEmpty && seen.add(n)) out.add(n);
    }

    await addUrl(input);

    try {
      final uri = Uri.parse(input);
      final fromParams = <String?>[
        uri.queryParameters['u'],
        uri.queryParameters['href'],
        uri.queryParameters['share_url'],
        uri.queryParameters['next'],
      ];
      for (final value in fromParams) {
        if (value == null || value.isEmpty) continue;
        await addUrl(Uri.decodeFull(value));
      }

      final maybeResolved = await _resolveRedirectUrl(input);
      if (maybeResolved != null && maybeResolved.isNotEmpty) {
        await addUrl(maybeResolved);
      }
    } catch (_) {
      // keep best-effort candidates only
    }

    return out;
  }

  Future<String?> _resolveRedirectUrl(String url) async {
    final response = await _dio.getUri<dynamic>(
      Uri.parse(url),
      options: Options(
        responseType: ResponseType.plain,
        headers: const {
          'User-Agent': _desktopUa,
          'Accept-Language': 'en-US,en;q=0.9',
        },
        validateStatus: (s) => s != null && s < 500,
      ),
    );

    final real = response.realUri;
    if (real.scheme.startsWith('http') && real.host.isNotEmpty) {
      var resolved = real.toString();
      resolved = resolved.replaceFirst(
        RegExp(r'^https?://fb\.com'),
        'https://www.facebook.com',
      );
      return resolved;
    }
    return null;
  }

  String? _extractVideoId(String url) {
    final patterns = [
      RegExp(r'[?&]v=(\d+)'),
      RegExp(r'/videos/(\d+)'),
      RegExp(r'/reel/(\d+)'),
      RegExp(r'/watch/?\?v=(\d+)'),
      RegExp(r'fb\.watch/([\w-]+)'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(url);
      if (m != null) return m.group(1);
    }
    return null;
  }

  String _hashId(String url) {
    final bytes = url.codeUnits;
    var h = 0;
    for (final b in bytes) {
      h = (h * 31 + b) & 0x7fffffff;
    }
    return 'fb_$h';
  }

  String _canonicalizeFacebookUrl(String input) {
    try {
      final uri = Uri.parse(input);
      final host = uri.host.toLowerCase();
      final isFacebookHost = host == 'facebook.com' ||
          host == 'www.facebook.com' ||
          host == 'm.facebook.com' ||
          host == 'web.facebook.com' ||
          host == 'mbasic.facebook.com';
      if (!isFacebookHost) return input;

      final path = uri.path;
      final lowerPath = path.toLowerCase();

      final keptQuery = <String, String>{};
      final v = uri.queryParameters['v'];
      if (v != null && v.isNotEmpty) keptQuery['v'] = v;
      final storyFbid = uri.queryParameters['story_fbid'];
      if (storyFbid != null && storyFbid.isNotEmpty) {
        keptQuery['story_fbid'] = storyFbid;
      }
      final id = uri.queryParameters['id'];
      if (id != null && id.isNotEmpty) keptQuery['id'] = id;

      // For reel/videos URLs, tracking params are noise and can trigger
      // inconsistent responses; for watch, keep `v`.
      final cleanQuery = switch (lowerPath) {
        var p when p.startsWith('/watch') => keptQuery,
        var p when p.startsWith('/reel/') => const <String, String>{},
        var p when p.contains('/videos/') => const <String, String>{},
        _ => keptQuery,
      };

      return Uri(
        scheme: 'https',
        host: 'www.facebook.com',
        path: path.isEmpty ? '/' : path,
        queryParameters: cleanQuery.isEmpty ? null : cleanQuery,
      ).toString();
    } catch (_) {
      return input;
    }
  }
}

class FacebookVideoData {
  const FacebookVideoData({
    required this.id,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.hdUrl,
    required this.sdUrl,
    required this.sourceUrl,
  });

  final String id;
  final String title;
  final String author;
  final String thumbnailUrl;
  final String? hdUrl;
  final String? sdUrl;
  final String sourceUrl;
}
