import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../../core/utils/video_link_parser.dart';
import '../../domain/entities/download_cancel_token.dart';
import '../../domain/entities/download_progress.dart';
import '../../domain/entities/download_stream.dart';
import '../../domain/entities/video_info.dart';
import '../../domain/repositories/video_repository.dart';
import '../datasources/tiktok_remote_datasource.dart';
import '../models/tiktok_download_stream.dart';
import '../services/segmented_download_service.dart';
import '../services/storage_service.dart';

class TiktokVideoRepositoryImpl implements VideoRepository {
  TiktokVideoRepositoryImpl(this._remote, {SegmentedDownloadService? downloader})
      : _downloader = downloader ?? SegmentedDownloadService();

  final TiktokRemoteDataSource _remote;
  final SegmentedDownloadService _downloader;

  @override
  Future<VideoBundle> getVideoBundle(String urlOrId) async {
    // One TikWM request yields both the metadata and the media URLs, so fetch
    // once and build both — previously this hit the API twice for one paste.
    final data = await _remote.getVideo(urlOrId);
    return VideoBundle(
      info: VideoInfo(
        id: data.id,
        title: _titleFrom(data),
        author: data.author,
        thumbnailUrl: data.cover,
        duration: data.duration > 0 ? Duration(seconds: data.duration) : null,
        platform: VideoSourcePlatform.tiktok,
      ),
      streams: _streamsFrom(data),
    );
  }

  List<DownloadStream> _streamsFrom(TiktokVideoData data) {
    final options = <TiktokDownloadStream>[];

    if (data.noWatermarkUrl.isNotEmpty) {
      options.add(TiktokDownloadStream(
        id: 'tiktok_${data.id}_nowm',
        label: 'No watermark',
        directUrl: data.noWatermarkUrl,
        estimatedBytes: data.noWatermarkBytes,
        height: 720,
        isAudio: false,
        noWatermark: true,
      ));
    }

    if (data.watermarkUrl.isNotEmpty &&
        data.watermarkUrl != data.noWatermarkUrl) {
      options.add(TiktokDownloadStream(
        id: 'tiktok_${data.id}_wm',
        label: 'Original (with TikTok watermark)',
        directUrl: data.watermarkUrl,
        estimatedBytes: data.watermarkBytes,
        height: 720,
        isAudio: false,
        noWatermark: false,
      ));
    }

    if (data.audioUrl.isNotEmpty) {
      options.add(TiktokDownloadStream(
        id: 'tiktok_${data.id}_audio',
        label: 'Audio only · MP3',
        directUrl: data.audioUrl,
        estimatedBytes: 0,
        height: 0,
        isAudio: true,
        noWatermark: true,
      ));
    }

    if (options.isEmpty) {
      throw StateError('No downloadable TikTok video found for this link');
    }
    return options;
  }

  @override
  Future<String> downloadStream({
    required DownloadStream stream,
    required String fileName,
    required String fileSuffix,
    void Function(DownloadProgress progress)? onProgress,
    DownloadCancelToken? cancelToken,
  }) async {
    if (stream is! TiktokDownloadStream) {
      throw ArgumentError(
        'TiktokVideoRepositoryImpl only downloads TiktokDownloadStream instances',
      );
    }

    final tempDir = await getTemporaryDirectory();
    final safe = _safeName(fileName);
    final file = File('${tempDir.path}/${safe}_$fileSuffix.${stream.extension}');

    try {
      await _downloader.download(
        url: stream.directUrl,
        output: file,
        headers: const {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Referer': 'https://www.tiktok.com/',
        },
        onProgress: onProgress,
        cancelToken: cancelToken,
      );

      cancelToken?.throwIfCancelled();
      return await StorageService.publishDownload(
        tempFile: file,
        isVideo: !stream.isAudio,
        isAudio: stream.isAudio,
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


  static String _safeName(String name) =>
      name.replaceAll(RegExp(r'[\\/:*?"<>|#]'), '_')
          .replaceAll(RegExp(r'[^\x20-\x7E]'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .trim();

  static String _titleFrom(TiktokVideoData data) {
    final desc = data.title.trim();
    if (desc.isNotEmpty) {
      return desc.length > 120 ? '${desc.substring(0, 120)}…' : desc;
    }
    return '@${data.author} on TikTok';
  }
}
