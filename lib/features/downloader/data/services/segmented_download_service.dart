import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../domain/entities/download_cancel_token.dart';
import '../../domain/entities/download_progress.dart';

class SegmentedDownloadService {
  SegmentedDownloadService({
    Dio? dio,
    this.maxConnections = 6,
    this.minSegmentBytes = 2 * 1024 * 1024,
  }) : _dio = dio ?? Dio();

  final Dio _dio;
  final int maxConnections;
  final int minSegmentBytes;

  static const _progressInterval = Duration(milliseconds: 100);

  // Force uncompressed transfer. With Content-Encoding compression on, a byte
  // range is a slice of the *compressed* stream — the pieces can't be stitched
  // back into the original file, and the client may even try to gunzip each
  // slice independently. `identity` guarantees ranges map to real file bytes.
  static const _noCompression = {'Accept-Encoding': 'identity'};

  Future<void> download({
    required String url,
    required File output,
    Map<String, String> headers = const {},
    void Function(DownloadProgress progress)? onProgress,
    DownloadCancelToken? cancelToken,
  }) async {
    cancelToken?.throwIfCancelled();
    try {
      final probe = await _probe(url, headers);

      final canSegment = probe.supportsRanges &&
          probe.totalBytes >= minSegmentBytes &&
          maxConnections > 1;

      if (!canSegment) {
        await _downloadSingle(
          url: url,
          output: output,
          headers: headers,
          knownTotal: probe.totalBytes,
          onProgress: onProgress,
          cancelToken: cancelToken,
        );
        return;
      }

      await _downloadSegmented(
        url: url,
        output: output,
        total: probe.totalBytes,
        headers: headers,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Exception _mapDioError(DioException e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) {
      return const DownloadException(
        'The host blocked this download (403). The file may be protected by '
        'Cloudflare or require a browser/login — open the link in a browser '
        'instead.',
      );
    }
    if (code == 404 || code == 410) {
      return const DownloadException(
        'File not found — the link may have expired or been removed.',
      );
    }
    if (code != null && code >= 400) {
      return DownloadException('Download failed (HTTP $code).');
    }
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout =>
        const DownloadException(
          'The download timed out. Check your connection and try again.',
        ),
      DioExceptionType.connectionError => const DownloadException(
          'Network error — check your connection and try again.',
        ),
      _ => const DownloadException(
          'Download failed. The link may be invalid or unreachable.',
        ),
    };
  }

  Future<void> _downloadSegmented({
    required String url,
    required File output,
    required int total,
    required Map<String, String> headers,
    void Function(DownloadProgress progress)? onProgress,
    DownloadCancelToken? cancelToken,
  }) async {
    final segments = _planSegments(total);
    final received = List<int>.filled(segments.length, 0);
    final partFiles = <File>[];

    var lastEmit = DateTime.fromMillisecondsSinceEpoch(0);
    void report({bool force = false}) {
      final now = DateTime.now();
      if (!force && now.difference(lastEmit) < _progressInterval) return;
      lastEmit = now;
      final done = received.fold<int>(0, (a, b) => a + b);
      onProgress?.call(DownloadProgress(
        fraction: total > 0 ? done / total : 0,
        downloadedBytes: done,
        totalBytes: total,
      ));
    }

    try {
      final futures = <Future<void>>[];
      for (var i = 0; i < segments.length; i++) {
        final seg = segments[i];
        final part = File('${output.path}.part$i');
        partFiles.add(part);
        final index = i;
        futures.add(_downloadRange(
          url: url,
          part: part,
          start: seg.start,
          end: seg.end,
          headers: headers,
          cancelToken: cancelToken,
          onChunk: (n) {
            received[index] += n;
            report();
          },
        ));
      }
      await Future.wait(futures);
      cancelToken?.throwIfCancelled();

      await _concatParts(partFiles, output);
      report(force: true);
    } finally {
      for (final p in partFiles) {
        try {
          if (await p.exists()) await p.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> _downloadRange({
    required String url,
    required File part,
    required int start,
    required int end,
    required Map<String, String> headers,
    required void Function(int chunkLength) onChunk,
    DownloadCancelToken? cancelToken,
  }) async {
    final dioCancel = CancelToken();
    final response = await _dio.get<ResponseBody>(
      url,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: true,
        receiveTimeout: const Duration(minutes: 30),
        headers: {...headers, ..._noCompression, 'Range': 'bytes=$start-$end'},
        validateStatus: (s) => s != null && s < 400,
      ),
      cancelToken: dioCancel,
    );

    final sink = part.openWrite();
    try {
      await for (final chunk in response.data!.stream) {
        if (cancelToken?.isCancelled ?? false) {
          dioCancel.cancel('cancelled');
          throw const DownloadCancelledException();
        }
        sink.add(chunk);
        onChunk(chunk.length);
      }
      await sink.flush();
      await sink.close();
    } on DioException catch (e) {
      await sink.close();
      if (CancelToken.isCancel(e) || (cancelToken?.isCancelled ?? false)) {
        throw const DownloadCancelledException();
      }
      rethrow;
    } catch (_) {
      await sink.close();
      rethrow;
    }
  }

  Future<void> _concatParts(List<File> parts, File output) async {
    final sink = output.openWrite();
    try {
      for (final part in parts) {
        await sink.addStream(part.openRead());
      }
      await sink.flush();
      await sink.close();
    } catch (_) {
      await sink.close();
      if (await output.exists()) await output.delete();
      rethrow;
    }
  }

  Future<void> _downloadSingle({
    required String url,
    required File output,
    required Map<String, String> headers,
    required int knownTotal,
    void Function(DownloadProgress progress)? onProgress,
    DownloadCancelToken? cancelToken,
  }) async {
    final dioCancel = CancelToken();
    await _dio.download(
      url,
      output.path,
      cancelToken: dioCancel,
      options: Options(
        followRedirects: true,
        receiveTimeout: const Duration(minutes: 30),
        headers: {...headers, ..._noCompression},
      ),
      onReceiveProgress: (rec, totalFromServer) {
        if (cancelToken?.isCancelled ?? false) {
          dioCancel.cancel('cancelled');
          throw const DownloadCancelledException();
        }
        final total = totalFromServer > 0 ? totalFromServer : knownTotal;
        onProgress?.call(DownloadProgress(
          fraction: total > 0 ? rec / total : 0,
          downloadedBytes: rec,
          totalBytes: total,
        ));
      },
    );
  }

  Future<_Probe> _probe(String url, Map<String, String> headers) async {
    try {
      final resp = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          headers: {...headers, ..._noCompression, 'Range': 'bytes=0-0'},
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      if (resp.statusCode == 206) {
        final contentRange = resp.headers.value('content-range');
        final total = _totalFromContentRange(contentRange);
        if (total > 0) return _Probe(totalBytes: total, supportsRanges: true);
      }

      // No 206 → range not honoured. Still try to learn the size for the
      // single-connection progress bar.
      final cl = int.tryParse(resp.headers.value('content-length') ?? '');
      final acceptsRanges = resp.headers.value('accept-ranges') == 'bytes';
      return _Probe(
        totalBytes: cl ?? 0,
        supportsRanges: acceptsRanges && (cl ?? 0) > 0,
      );
    } catch (_) {
      // Probe failed — fall back to a plain single download.
      return const _Probe(totalBytes: 0, supportsRanges: false);
    }
  }

  int _totalFromContentRange(String? header) {
    if (header == null) return 0;
    final m = RegExp(r'/(\d+)\s*$').firstMatch(header.trim());
    return m != null ? int.tryParse(m.group(1)!) ?? 0 : 0;
  }

  List<_Segment> _planSegments(int total) {
    final byChunk = (total / minSegmentBytes).floor();
    final count = byChunk.clamp(1, maxConnections);
    final size = (total / count).ceil();

    final segments = <_Segment>[];
    var start = 0;
    while (start < total) {
      final end = (start + size - 1) < total - 1 ? start + size - 1 : total - 1;
      segments.add(_Segment(start, end));
      start = end + 1;
    }
    return segments;
  }
}

class DownloadException implements Exception {
  const DownloadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _Probe {
  const _Probe({required this.totalBytes, required this.supportsRanges});

  final int totalBytes;
  final bool supportsRanges;
}

class _Segment {
  const _Segment(this.start, this.end);

  final int start;
  final int end;
}
