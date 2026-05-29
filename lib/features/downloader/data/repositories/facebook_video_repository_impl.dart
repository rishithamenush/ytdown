import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/utils/video_link_parser.dart';
import '../../domain/entities/download_cancel_token.dart';
import '../../domain/entities/download_progress.dart';
import '../../domain/entities/download_stream.dart';
import '../../domain/entities/video_info.dart';
import '../../domain/repositories/video_repository.dart';
import '../datasources/facebook_remote_datasource.dart';
import '../models/facebook_download_stream.dart';
import '../services/storage_service.dart';

class FacebookVideoRepositoryImpl implements VideoRepository {
  FacebookVideoRepositoryImpl(this._remote, {Dio? dio}) : _dio = dio ?? Dio();

  final FacebookRemoteDataSource _remote;
  final Dio _dio;

  @override
  Future<VideoBundle> getVideoBundle(String urlOrId) async {
    // A single (slow) gateway scrape produces both the metadata and the CDN
    // URLs, so fetch once and build both from the same result.
    final data = await _remote.getVideo(urlOrId);
    return VideoBundle(
      info: VideoInfo(
        id: data.id,
        title: _trimTitle(data.title),
        author: data.author,
        thumbnailUrl: data.thumbnailUrl,
        platform: VideoSourcePlatform.facebook,
      ),
      streams: _streamsFrom(data),
    );
  }

  List<DownloadStream> _streamsFrom(FacebookVideoData data) {
    final options = <FacebookDownloadStream>[];

    if (data.hdUrl != null && data.hdUrl!.isNotEmpty) {
      options.add(FacebookDownloadStream(
        id: 'fb_${data.id}_hd',
        label: 'HD (best quality)',
        directUrl: data.hdUrl!,
        height: 720,
        isAudio: false,
      ));
    }

    if (data.sdUrl != null && data.sdUrl!.isNotEmpty) {
      options.add(FacebookDownloadStream(
        id: 'fb_${data.id}_sd',
        label: 'SD (smaller file)',
        directUrl: data.sdUrl!,
        height: 360,
        isAudio: false,
      ));
    }

    if (options.isEmpty) {
      throw StateError(
        'No downloadable Facebook video found for this link.',
      );
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
    if (stream is! FacebookDownloadStream) {
      throw ArgumentError(
        'FacebookVideoRepositoryImpl only downloads '
        'FacebookDownloadStream instances',
      );
    }

    final tempDir = await getTemporaryDirectory();
    final safe = _safeName(fileName);
    final file =
        File('${tempDir.path}/${safe}_$fileSuffix.${stream.extension}');
    final dioCancel = CancelToken();

    try {
      await _dio.download(
        stream.directUrl,
        file.path,
        cancelToken: dioCancel,
        options: Options(
          followRedirects: true,
          receiveTimeout: const Duration(minutes: 30),
          headers: {
            // Same desktop UA used by the data source — Facebook's video CDN
            // sometimes returns a 403 for the default dart-io UA.
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                    '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Referer': 'https://www.facebook.com/',
          },
        ),
        onReceiveProgress: (received, total) {
          if (cancelToken?.isCancelled ?? false) {
            dioCancel.cancel('cancelled');
            throw const DownloadCancelledException();
          }
          onProgress?.call(
            DownloadProgress(
              fraction: total > 0 ? received / total : 0,
              downloadedBytes: received,
              totalBytes: total,
            ),
          );
        },
      );

      cancelToken?.throwIfCancelled();
      return await StorageService.publishDownload(
        tempFile: file,
        isVideo: !stream.isAudio,
        isAudio: stream.isAudio,
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e) || cancelToken?.isCancelled == true) {
        throw const DownloadCancelledException();
      }
      rethrow;
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

  static String _trimTitle(String title) {
    final t = title.trim();
    if (t.isEmpty) return 'Facebook video';
    if (t.length > 120) return '${t.substring(0, 120)}…';
    return t;
  }
}
