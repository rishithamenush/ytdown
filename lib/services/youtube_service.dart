import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

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
}

class DownloadCancelledException implements Exception {
  @override
  String toString() => 'Download cancelled';
}

class DownloadableStream {
  DownloadableStream({
    required this.info,
    required this.label,
    required this.extension,
  });

  final StreamInfo info;
  final String label;
  final String extension;

  bool get isVideo => info is MuxedStreamInfo;
}

class YoutubeService {
  YoutubeService() : _yt = YoutubeExplode();

  final YoutubeExplode _yt;

  Future<Video> getVideo(String urlOrId) async {
    final id = VideoId(urlOrId);
    return _yt.videos.get(id);
  }

  Future<List<DownloadableStream>> getDownloadOptions(String urlOrId) async {
    final id = VideoId(urlOrId);
    final manifest = await _yt.videos.streamsClient.getManifest(id);
    final options = <DownloadableStream>[];

    for (final stream in manifest.muxed) {
      options.add(
        DownloadableStream(
          info: stream,
          label: '${stream.qualityLabel} (video + audio)',
          extension: stream.container.name,
        ),
      );
    }

    for (final stream in manifest.audioOnly) {
      options.add(
        DownloadableStream(
          info: stream,
          label: 'Audio ${stream.bitrate}',
          extension: stream.container.name,
        ),
      );
    }

    options.sort((a, b) {
      final aMuxed = a.info is MuxedStreamInfo;
      final bMuxed = b.info is MuxedStreamInfo;
      if (aMuxed != bMuxed) return aMuxed ? -1 : 1;
      return b.info.bitrate.compareTo(a.info.bitrate);
    });

    return options;
  }

  Future<String> downloadStream({
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

    final stream = _yt.videos.streamsClient.get(streamInfo);
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

    final sink = file.openWrite();
    Future<void> abort() async {
      await sink.flush();
      await sink.close();
      if (await file.exists()) {
        await file.delete();
      }
      throw DownloadCancelledException();
    }

    try {
      await for (final chunk in stream) {
        if (cancelToken?.isCancelled ?? false) {
          await abort();
        }
        sink.add(chunk);
        downloaded += chunk.length;
        report();
      }
      await sink.flush();
      await sink.close();
    } on DownloadCancelledException {
      rethrow;
    } catch (e) {
      await sink.close();
      if (await file.exists()) {
        await file.delete();
      }
      rethrow;
    }

    final publicPath = await StorageService.publishDownload(
      tempFile: file,
      isVideo: isVideo,
    );

    if (await file.exists()) {
      await file.delete();
    }

    return publicPath;
  }

  void dispose() {
    _yt.close();
  }
}
