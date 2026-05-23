import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'merge_service.dart';
import 'storage_service.dart';

class DownloadProgress {
  const DownloadProgress({
    required this.fraction,
    required this.downloadedBytes,
    required this.totalBytes,
  });

  final double fraction;
  final int downloadedBytes;
  final int totalBytes;

  bool get hasTotal => totalBytes > 0;

  int get percent => hasTotal ? (fraction * 100).round().clamp(0, 100) : 0;
}

class DownloadCancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;

  void throwIfCancelled() {
    if (_cancelled) throw DownloadCancelledException();
  }
}

class DownloadCancelledException implements Exception {
  @override
  String toString() => 'Download cancelled';
}

class DownloadableStream {
  DownloadableStream._({
    required this.id,
    required this.label,
    required this.extension,
    required this.isVideo,
    this.singleStream,
    this.videoStream,
    this.audioStream,
  });

  factory DownloadableStream.single({
    required StreamInfo stream,
    required String label,
  }) {
    return DownloadableStream._(
      id: 'single_${stream.tag}',
      label: label,
      extension: stream.container.name,
      isVideo: stream is MuxedStreamInfo,
      singleStream: stream,
    );
  }

  factory DownloadableStream.merged({
    required VideoOnlyStreamInfo video,
    required AudioOnlyStreamInfo audio,
    required String label,
  }) {
    return DownloadableStream._(
      id: 'merged_${video.tag}_${audio.tag}',
      label: label,
      extension: 'mp4',
      isVideo: true,
      videoStream: video,
      audioStream: audio,
    );
  }

  final String id;
  final String label;
  final String extension;
  final bool isVideo;
  final StreamInfo? singleStream;
  final VideoOnlyStreamInfo? videoStream;
  final AudioOnlyStreamInfo? audioStream;

  bool get isMerged => videoStream != null && audioStream != null;

  int? get videoHeight {
    if (videoStream != null) return videoStream!.videoResolution.height;
    final single = singleStream;
    if (single is MuxedStreamInfo) return single.videoResolution.height;
    return null;
  }

  int get estimatedSizeBytes {
    if (videoStream != null && audioStream != null) {
      return videoStream!.size.totalBytes + audioStream!.size.totalBytes;
    }
    return singleStream?.size.totalBytes ?? 0;
  }
}

class YoutubeService {
  YoutubeService() : _yt = YoutubeExplode();

  final YoutubeExplode _yt;

  static final _manifestClients = [
    YoutubeApiClient.androidVr,
    YoutubeApiClient.safari,
    YoutubeApiClient.ios,
    YoutubeApiClient.android,
  ];

  Future<Video> getVideo(String urlOrId) async {
    final id = VideoId(urlOrId);
    return _yt.videos.get(id);
  }

  Future<StreamManifest> _getManifest(VideoId id) {
    return _yt.videos.streamsClient.getManifest(id, ytClients: _manifestClients);
  }

  Future<List<DownloadableStream>> getDownloadOptions(String urlOrId) async {
    final id = VideoId(urlOrId);
    final manifest = await _getManifest(id);
    final options = <DownloadableStream>[];

    final bestAudio = manifest.audioOnly.isNotEmpty
        ? manifest.audioOnly.withHighestBitrate()
        : null;

    if (bestAudio != null) {
      final bestPerQuality = <int, VideoOnlyStreamInfo>{};
      void collectVideos(bool mp4Only) {
        for (final stream in manifest.videoOnly) {
          if (mp4Only && stream.container != StreamContainer.mp4) continue;
          final height = stream.videoResolution.height;
          final current = bestPerQuality[height];
          if (current == null || stream.bitrate.compareTo(current.bitrate) > 0) {
            bestPerQuality[height] = stream;
          }
        }
      }

      collectVideos(true);
      if (bestPerQuality.isEmpty) collectVideos(false);

      final mergedVideos = bestPerQuality.values.toList()
        ..sort((a, b) => b.videoResolution.height.compareTo(a.videoResolution.height));

      for (final video in mergedVideos) {
        final height = video.videoResolution.height;
        options.add(
          DownloadableStream.merged(
            video: video,
            audio: bestAudio,
            label: '${video.qualityLabel} (${height}p · video + audio)',
          ),
        );
      }
    }

    for (final stream in manifest.muxed) {
      final height = stream.videoResolution.height;
      if (bestAudio != null &&
          options.any((o) => o.isMerged && o.videoStream!.videoResolution.height <= height)) {
        continue;
      }
      options.add(
        DownloadableStream.single(
          stream: stream,
          label: '${stream.qualityLabel} (${height}p · quick, no merge)',
        ),
      );
    }

    for (final stream in manifest.audioOnly) {
      options.add(
        DownloadableStream.single(
          stream: stream,
          label: 'Audio only · ${stream.bitrate}',
        ),
      );
    }

    return options;
  }

  Future<String> downloadOption({
    required DownloadableStream option,
    required String fileName,
    required String fileSuffix,
    void Function(DownloadProgress progress)? onProgress,
    DownloadCancelToken? cancelToken,
  }) {
    if (option.isMerged) {
      return _downloadMerged(
        videoStream: option.videoStream!,
        audioStream: option.audioStream!,
        fileName: fileName,
        fileSuffix: fileSuffix,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    }
    return _downloadSingle(
      streamInfo: option.singleStream!,
      fileName: fileName,
      isVideo: option.isVideo,
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
    final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final videoFile = File(
      '${tempDir.path}/${safeName}_${fileSuffix}_v.${videoStream.container.name}',
    );
    final audioFile = File(
      '${tempDir.path}/${safeName}_${fileSuffix}_a.${audioStream.container.name}',
    );
    final mergedFile = File('${tempDir.path}/${safeName}_$fileSuffix.mp4');

    final videoBytes = videoStream.size.totalBytes;
    final audioBytes = audioStream.size.totalBytes;
    const mergeWeight = 0.05;
    final totalBytes = ((videoBytes + audioBytes) / (1 - mergeWeight)).round();

    var downloaded = 0;

    void report() {
      onProgress?.call(
        DownloadProgress(
          fraction: totalBytes > 0 ? downloaded / totalBytes : 0,
          downloadedBytes: downloaded,
          totalBytes: totalBytes,
        ),
      );
    }

    try {
      cancelToken?.throwIfCancelled();
      await _downloadStreamToFile(
        streamInfo: videoStream,
        file: videoFile,
        cancelToken: cancelToken,
        onChunk: (n) {
          downloaded += n;
          report();
        },
      );

      cancelToken?.throwIfCancelled();
      await _downloadStreamToFile(
        streamInfo: audioStream,
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

      final publicPath = await StorageService.publishDownload(
        tempFile: mergedFile,
        isVideo: true,
      );
      return publicPath;
    } on DownloadCancelledException {
      rethrow;
    } finally {
      for (final f in [videoFile, audioFile, mergedFile]) {
        if (await f.exists()) await f.delete();
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
    final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final ext = streamInfo.container.name;
    final file = File('${tempDir.path}/${safeName}_$fileSuffix.$ext');

    final total = streamInfo.size.totalBytes;
    var downloaded = 0;

    void report() {
      onProgress?.call(
        DownloadProgress(
          fraction: total > 0 ? downloaded / total : 0,
          downloadedBytes: downloaded,
          totalBytes: total,
        ),
      );
    }

    report();

    try {
      await _downloadStreamToFile(
        streamInfo: streamInfo,
        file: file,
        cancelToken: cancelToken,
        onChunk: (n) {
          downloaded += n;
          report();
        },
      );

      final publicPath = await StorageService.publishDownload(
        tempFile: file,
        isVideo: isVideo,
      );
      return publicPath;
    } on DownloadCancelledException {
      rethrow;
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> _downloadStreamToFile({
    required StreamInfo streamInfo,
    required File file,
    DownloadCancelToken? cancelToken,
    required void Function(int chunkLength) onChunk,
  }) async {
    final stream = _yt.videos.streamsClient.get(streamInfo);
    final sink = file.openWrite();

    try {
      await for (final chunk in stream) {
        cancelToken?.throwIfCancelled();
        sink.add(chunk);
        onChunk(chunk.length);
      }
      await sink.flush();
      await sink.close();
    } on DownloadCancelledException {
      await sink.close();
      if (await file.exists()) await file.delete();
      rethrow;
    } catch (e) {
      await sink.close();
      if (await file.exists()) await file.delete();
      rethrow;
    }
  }

  void dispose() {
    _yt.close();
  }
}
