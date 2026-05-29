import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../../core/utils/video_link_parser.dart';
import '../../domain/entities/download_cancel_token.dart';
import '../../domain/entities/download_progress.dart';
import '../../domain/entities/download_stream.dart';
import '../../domain/entities/video_info.dart';
import '../../domain/repositories/video_repository.dart';
import '../datasources/direct_link_remote_datasource.dart';
import '../models/direct_link_download_stream.dart';
import '../services/direct_link_cookie_store.dart';
import '../services/direct_link_http_profile.dart';
import '../services/segmented_download_service.dart';
import '../services/storage_service.dart';

/// Handles plain "direct link" downloads: the URL already points at a file, so
/// there's nothing to scrape — probe it for a name/size, then fetch it with
/// the segmented (multi-connection) downloader.
class DirectLinkVideoRepositoryImpl implements VideoRepository {
  DirectLinkVideoRepositoryImpl(
    this._remote,
    this._cookieStore, {
    SegmentedDownloadService? downloader,
  }) : _downloader = downloader ?? SegmentedDownloadService();

  final DirectLinkRemoteDataSource _remote;
  final DirectLinkCookieStore _cookieStore;
  final SegmentedDownloadService _downloader;

  @override
  Future<VideoBundle> getVideoBundle(String urlOrId) async {
    final host = Uri.tryParse(urlOrId)?.host ?? '';
    final probe = await _remote.probe(
      urlOrId,
      cookieHeader: _cookieStore.cookieHeaderForHost(host),
    );
    final ext = _resolveExtension(probe, urlOrId);
    final kind = _kindFor(ext);
    final id = 'direct_${_hashId(urlOrId)}';
    final base = _baseName(probe.fileName);

    return VideoBundle(
      info: VideoInfo(
        id: id,
        title: base.isEmpty ? 'Download' : base,
        author: _hostOf(urlOrId),
        thumbnailUrl: '',
        platform: VideoSourcePlatform.directLink,
      ),
      streams: [
        DirectLinkDownloadStream(
          id: id,
          label: switch (kind) {
            DirectFileKind.video => 'Video file',
            DirectFileKind.audio => 'Audio file',
            DirectFileKind.other => 'File',
          },
          directUrl: urlOrId,
          fileExtension: ext,
          kind: kind,
          estimatedSizeBytes: probe.sizeBytes,
          requiresBrowserSession: probe.requiresBrowserSession,
        ),
      ],
    );
  }

  @override
  Future<String> downloadStream({
    required DownloadStream stream,
    required String fileName,
    required String fileSuffix,
    void Function(DownloadProgress progress)? onProgress,
    DownloadCancelToken? cancelToken,
  }) async {
    if (stream is! DirectLinkDownloadStream) {
      throw ArgumentError(
        'DirectLinkVideoRepositoryImpl only downloads '
        'DirectLinkDownloadStream instances',
      );
    }

    final tempDir = await getTemporaryDirectory();
    final safe = _safeName(fileName);
    final file =
        File('${tempDir.path}/${safe}_$fileSuffix.${stream.extension}');

    final host = Uri.tryParse(stream.directUrl)?.host ?? '';
    final cookies = _cookieStore.cookieHeaderForHost(host);

    try {
      await _downloader.download(
        url: stream.directUrl,
        output: file,
        headers: DirectLinkHttpProfile.headersFor(
          stream.directUrl,
          cookieHeader: cookies,
        ),
        onProgress: onProgress,
        cancelToken: cancelToken,
      );

      cancelToken?.throwIfCancelled();
      return await StorageService.publishDownload(
        tempFile: file,
        isVideo: stream.kind == DirectFileKind.video,
        isAudio: stream.kind == DirectFileKind.audio,
      );
    } on DownloadCancelledException {
      rethrow;
    } finally {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  @override
  void dispose() {}

  // ── helpers ────────────────────────────────────────────────────────────────
  String _resolveExtension(DirectLinkFileInfo probe, String url) {
    final fromName = _extOf(probe.fileName);
    if (fromName != null) return fromName;
    final path = Uri.tryParse(url)?.path ?? '';
    final fromUrl = VideoLinkParser.fileExtensionOf(path);
    if (fromUrl != null) return fromUrl;
    return _extFromContentType(probe.contentType) ?? 'bin';
  }

  DirectFileKind _kindFor(String ext) {
    if (VideoLinkParser.videoExtensions.contains(ext)) {
      return DirectFileKind.video;
    }
    if (VideoLinkParser.audioExtensions.contains(ext)) {
      return DirectFileKind.audio;
    }
    return DirectFileKind.other;
  }

  String? _extOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot == -1 || dot == name.length - 1) return null;
    return name.substring(dot + 1).toLowerCase();
  }

  String _baseName(String name) {
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  String? _extFromContentType(String contentType) {
    final type = contentType.split(';').first.trim().toLowerCase();
    return switch (type) {
      'video/mp4' => 'mp4',
      'video/webm' => 'webm',
      'video/x-matroska' => 'mkv',
      'video/quicktime' => 'mov',
      'audio/mpeg' => 'mp3',
      'audio/mp4' || 'audio/x-m4a' => 'm4a',
      'audio/ogg' => 'ogg',
      'audio/flac' => 'flac',
      'application/zip' => 'zip',
      'application/pdf' => 'pdf',
      'application/vnd.android.package-archive' => 'apk',
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      _ => null,
    };
  }

  String _hostOf(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    return host.isEmpty ? 'Direct link' : host;
  }

  String _hashId(String url) {
    var h = 0;
    for (final c in url.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h.toString();
  }

  static String _safeName(String name) =>
      name.replaceAll(RegExp(r'[\\/:*?"<>|#]'), '_')
          .replaceAll(RegExp(r'[^\x20-\x7E]'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .trim();

}
