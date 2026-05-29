import 'package:dio/dio.dart';

import '../services/direct_link_http_profile.dart';
import 'direct_link_access_exception.dart';

class DirectLinkRemoteDataSource {
  DirectLinkRemoteDataSource({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<DirectLinkFileInfo> probe(
    String url, {
    String? cookieHeader,
  }) async {
    final headers = DirectLinkHttpProfile.headersFor(
      url,
      cookieHeader: cookieHeader,
    );

    final viaHead = await _tryHead(url, headers);
    if (viaHead != null) return viaHead;

    final viaRange = await _tryRangeGet(url, headers);
    if (viaRange != null) return viaRange;

    final status = await _peekStatus(url, headers);
    if (_isBlockedStatus(status) && cookieHeader == null) {
      return DirectLinkFileInfo(
        fileName: _nameFromUrl(url),
        sizeBytes: 0,
        contentType: '',
        requiresBrowserSession: true,
      );
    }

    if (_isBlockedStatus(status)) {
      throw DirectLinkAccessException(
        _messageForStatus(status) ??
            'Could not access this file after browser verification.',
      );
    }

    return DirectLinkFileInfo(
      fileName: _nameFromUrl(url),
      sizeBytes: 0,
      contentType: '',
    );
  }

  bool _isBlockedStatus(int? code) =>
      code == 401 || code == 403 || (code != null && code >= 400 && code < 500);

  Future<DirectLinkFileInfo?> _tryHead(
    String url,
    Map<String, String> headers,
  ) async {
    try {
      final resp = await _dio.head<void>(
        url,
        options: Options(
          followRedirects: true,
          headers: headers,
          validateStatus: (s) => s != null && s < 400,
        ),
      );
      return _fromHeaders(resp.headers, url);
    } catch (_) {
      return null;
    }
  }

  Future<DirectLinkFileInfo?> _tryRangeGet(
    String url,
    Map<String, String> headers,
  ) async {
    try {
      final resp = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          headers: {...headers, 'Range': 'bytes=0-0'},
          validateStatus: (s) => s != null && s < 400,
        ),
      );

      // A 206 carries the full size in Content-Range: "bytes 0-0/<total>".
      final total = _totalFromContentRange(resp.headers.value('content-range'));
      final base = _fromHeaders(resp.headers, url);
      return DirectLinkFileInfo(
        fileName: base?.fileName ?? _nameFromUrl(url),
        sizeBytes: total > 0 ? total : (base?.sizeBytes ?? 0),
        contentType: base?.contentType ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  DirectLinkFileInfo? _fromHeaders(Headers headers, String url) {
    final disposition = headers.value('content-disposition');
    final fromDisposition = _nameFromDisposition(disposition);
    final size = int.tryParse(headers.value('content-length') ?? '') ?? 0;
    final type = headers.value('content-type') ?? '';
    return DirectLinkFileInfo(
      fileName: fromDisposition ?? _nameFromUrl(url),
      sizeBytes: size,
      contentType: type,
    );
  }

  /// Parses `Content-Disposition: attachment; filename="x.mkv"` and the
  /// RFC 5987 `filename*=UTF-8''x.mkv` form.
  String? _nameFromDisposition(String? header) {
    if (header == null || header.isEmpty) return null;

    final star = RegExp(
      r"""filename\*\s*=\s*[^']*''([^;]+)""",
      caseSensitive: false,
    ).firstMatch(header);
    if (star != null) {
      final raw = star.group(1)!.trim();
      try {
        final decoded = Uri.decodeComponent(raw);
        if (decoded.isNotEmpty) return decoded;
      } catch (_) {
        if (raw.isNotEmpty) return raw;
      }
    }

    final plain = RegExp(
      r'''filename\s*=\s*"?([^";]+)"?''',
      caseSensitive: false,
    ).firstMatch(header);
    final name = plain?.group(1)?.trim();
    return (name != null && name.isNotEmpty) ? name : null;
  }

  String _nameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isNotEmpty) {
        final last = Uri.decodeComponent(segments.last);
        if (last.isNotEmpty) return last;
      }
    } catch (_) {}
    return 'download';
  }

  int _totalFromContentRange(String? header) {
    if (header == null) return 0;
    final m = RegExp(r'/(\d+)\s*$').firstMatch(header.trim());
    return m != null ? int.tryParse(m.group(1)!) ?? 0 : 0;
  }

  Future<int?> _peekStatus(String url, Map<String, String> headers) async {
    try {
      final resp = await _dio.head<void>(
        url,
        options: Options(
          followRedirects: true,
          headers: headers,
          validateStatus: (_) => true,
        ),
      );
      return resp.statusCode;
    } catch (_) {
      return null;
    }
  }

  String? _messageForStatus(int? code) {
    if (code == null) return null;
    return switch (code) {
      401 || 403 =>
        'This host blocked the download (HTTP $code). Some sites (e.g. '
        'file-examples.com) use Cloudflare and only allow downloads from a '
        'browser — open the link in Chrome/Safari and save from there.',
      404 || 410 =>
        'File not found — the link may have expired or been removed.',
      >= 400 && < 500 => 'Could not access this file (HTTP $code).',
      _ => null,
    };
  }
}

class DirectLinkFileInfo {
  const DirectLinkFileInfo({
    required this.fileName,
    required this.sizeBytes,
    required this.contentType,
    this.requiresBrowserSession = false,
  });

  final String fileName;
  final int sizeBytes;
  final String contentType;

  final bool requiresBrowserSession;
}
