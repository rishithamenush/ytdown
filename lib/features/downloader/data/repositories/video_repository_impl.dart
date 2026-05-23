import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../domain/entities/download_cancel_token.dart';
import '../../domain/entities/download_progress.dart';
import '../../domain/entities/download_stream.dart';
import '../../../../core/utils/video_link_parser.dart';
import '../../domain/entities/video_info.dart';
import '../../domain/repositories/video_repository.dart';
import '../datasources/youtube_remote_datasource.dart';
import '../models/youtube_download_stream.dart';
import '../services/merge_service.dart';
import '../services/storage_service.dart';

/// YouTube-backed implementation of [VideoRepository]. Translates the data-
/// source's youtube_explode types into pure domain entities and orchestrates
/// merge + storage for completed downloads.
class VideoRepositoryImpl implements VideoRepository {
  VideoRepositoryImpl(this._remote);

  final YoutubeRemoteDataSource _remote;

  @override
  Future<VideoInfo> getVideoInfo(String urlOrId) async {
    final video = await _remote.getVideo(urlOrId);
    return VideoInfo(
      id: video.id.value,
      title: video.title,
      author: video.author,
      thumbnailUrl: video.thumbnails.highResUrl,
      duration: video.duration,
      platform: VideoSourcePlatform.youtube,
    );
  }

  @override
  Future<List<DownloadStream>> getDownloadStreams(String urlOrId) async {
    final manifest = await _remote.getManifest(urlOrId);
    final options = <YoutubeDownloadStream>[];

    final bestAudio = manifest.audioOnly.isNotEmpty
        ? manifest.audioOnly.withHighestBitrate()
        : null;

    if (bestAudio != null) {
      final bestPerQuality = <int, VideoOnlyStreamInfo>{};
      void collect(bool mp4Only) {
        for (final stream in manifest.videoOnly) {
          if (mp4Only && stream.container != StreamContainer.mp4) continue;
          final height = stream.videoResolution.height;
          final current = bestPerQuality[height];
          if (current == null || stream.bitrate.compareTo(current.bitrate) > 0) {
            bestPerQuality[height] = stream;
          }
        }
      }

      collect(true);
      if (bestPerQuality.isEmpty) collect(false);

      final merged = bestPerQuality.values.toList()
        ..sort((a, b) =>
            b.videoResolution.height.compareTo(a.videoResolution.height));

      for (final video in merged) {
        final h = video.videoResolution.height;
        options.add(YoutubeDownloadStream.merged(
          video: video,
          audio: bestAudio,
          label: '${video.qualityLabel} (${h}p · video + audio)',
        ));
      }
    }

    for (final stream in manifest.muxed) {
      final h = stream.videoResolution.height;
      final alreadyCovered = bestAudio != null &&
          options.any((o) =>
              o.isMerged && o.videoStream!.videoResolution.height <= h);
      if (alreadyCovered) continue;
      options.add(YoutubeDownloadStream.single(
        stream: stream,
        label: '${stream.qualityLabel} (${h}p · quick, no merge)',
      ));
    }

    for (final stream in manifest.audioOnly) {
      options.add(YoutubeDownloadStream.single(
        stream: stream,
        label: 'Audio only · ${stream.bitrate}',
      ));
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
  }) {
    if (stream is! YoutubeDownloadStream) {
      throw ArgumentError(
        'VideoRepositoryImpl only downloads YoutubeDownloadStream instances',
      );
    }
    if (stream.isMerged) {
      return _downloadMerged(
        videoStream: stream.videoStream!,
        audioStream: stream.audioStream!,
        fileName: fileName,
        fileSuffix: fileSuffix,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    }
    return _downloadSingle(
      streamInfo: stream.singleStream!,
      fileName: fileName,
      isVideo: stream.isVideo,
      fileSuffix: fileSuffix,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }

  Future<String> _downloadMerged({
    required VideoOnlyStreamInfo videoStream,
    required AudioOnlyStreamInfo audioStream,
    required String fileName,
    required String fileSuffix,
    void Function(DownloadProgress progress)? onProgress,
    DownloadCancelToken? cancelToken,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final safe = _safeName(fileName);
    final videoFile = File(
      '${tempDir.path}/${safe}_${fileSuffix}_v.${videoStream.container.name}',
    );
    final audioFile = File(
      '${tempDir.path}/${safe}_${fileSuffix}_a.${audioStream.container.name}',
    );
    final mergedFile = File('${tempDir.path}/${safe}_$fileSuffix.mp4');

    // Reserve ~5% of the progress budget for the ffmpeg merge step so the
    // bar doesn't snap from 95% → 100% at the very end.
    final videoBytes = videoStream.size.totalBytes;
    final audioBytes = audioStream.size.totalBytes;
    const mergeWeight = 0.05;
    final totalBytes = ((videoBytes + audioBytes) / (1 - mergeWeight)).round();

    var downloaded = 0;
    void report() {
      onProgress?.call(DownloadProgress(
        fraction: totalBytes > 0 ? downloaded / totalBytes : 0,
        downloadedBytes: downloaded,
        totalBytes: totalBytes,
      ));
    }

    try {
      cancelToken?.throwIfCancelled();
      await _streamToFile(
        info: videoStream,
        file: videoFile,
        cancelToken: cancelToken,
        onChunk: (n) {
          downloaded += n;
          report();
        },
      );

      cancelToken?.throwIfCancelled();
      await _streamToFile(
        info: audioStream,
        file: audioFile,
        cancelToken: cancelToken,
        onChunk: (n) {
          downloaded += n;
          report();
        },
      );

      cancelToken?.throwIfCancelled();
      await MergeService.mergeVideoAndAudio(
        videoPath: videoFile.path,
        audioPath: audioFile.path,
        outputPath: mergedFile.path,
      );
      downloaded = totalBytes;
      report();

      return StorageService.publishDownload(
        tempFile: mergedFile,
        isVideo: true,
      );
    } on DownloadCancelledException {
      rethrow;
    } finally {
      // Best-effort: media_store_plus deletes the merged file itself on
      // success, so PathNotFoundException here is expected.
      for (final f in [videoFile, audioFile, mergedFile]) {
        try {
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
    }
  }

  Future<String> _downloadSingle({
    required StreamInfo streamInfo,
    required String fileName,
    required bool isVideo,
    required String fileSuffix,
    void Function(DownloadProgress progress)? onProgress,
    DownloadCancelToken? cancelToken,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final safe = _safeName(fileName);
    final ext = streamInfo.container.name;
    final file = File('${tempDir.path}/${safe}_$fileSuffix.$ext');

    final total = streamInfo.size.totalBytes;
    var downloaded = 0;
    void report() {
      onProgress?.call(DownloadProgress(
        fraction: total > 0 ? downloaded / total : 0,
        downloadedBytes: downloaded,
        totalBytes: total,
      ));
    }

    report();

    try {
      await _streamToFile(
        info: streamInfo,
        file: file,
        cancelToken: cancelToken,
        onChunk: (n) {
          downloaded += n;
          report();
        },
      );
      return StorageService.publishDownload(tempFile: file, isVideo: isVideo);
    } on DownloadCancelledException {
      rethrow;
    } finally {
      // Best-effort: media_store_plus deletes the temp file itself on success.
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  Future<void> _streamToFile({
    required StreamInfo info,
    required File file,
    required void Function(int chunkLength) onChunk,
    DownloadCancelToken? cancelToken,
  }) async {
    final stream = _remote.openStream(info);
    final sink = file.openWrite();
    try {
      await for (final chunk in stream) {
        cancelToken?.throwIfCancelled();
        sink.add(chunk);
        onChunk(chunk.length);
      }
      await sink.flush();
      await sink.close();
    } catch (_) {
      await sink.close();
      if (await file.exists()) await file.delete();
      rethrow;
    }
  }

  // '#' is stripped because media_store_plus parses the temp file path as a
  // URI to derive the saved filename, and '#' would truncate it at the
  // fragment delimiter. YouTube titles rarely contain it, but guarding here
  // matches the TikTok repo and avoids a latent silent-failure mode.
  static String _safeName(String name) =>
      name.replaceAll(RegExp(r'[\\/:*?"<>|#]'), '_');

  @override
  void dispose() => _remote.dispose();
}
