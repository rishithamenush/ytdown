import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../domain/entities/download_stream.dart';

class YoutubeDownloadStream implements DownloadStream {
  YoutubeDownloadStream._({
    required this.id,
    required this.label,
    required this.extension,
    required this.isVideo,
    this.singleStream,
    this.videoStream,
    this.audioStream,
  });

  factory YoutubeDownloadStream.single({
    required StreamInfo stream,
    required String label,
  }) {
    return YoutubeDownloadStream._(
      id: 'single_${stream.tag}',
      label: label,
      extension: stream.container.name,
      isVideo: stream is MuxedStreamInfo,
      singleStream: stream,
    );
  }

  factory YoutubeDownloadStream.merged({
    required VideoOnlyStreamInfo video,
    required AudioOnlyStreamInfo audio,
    required String label,
  }) {
    return YoutubeDownloadStream._(
      id: 'merged_${video.tag}_${audio.tag}',
      label: label,
      extension: 'mp4',
      isVideo: true,
      videoStream: video,
      audioStream: audio,
    );
  }

  @override
  final String id;
  @override
  final String label;
  @override
  final String extension;
  @override
  final bool isVideo;

  final StreamInfo? singleStream;
  final VideoOnlyStreamInfo? videoStream;
  final AudioOnlyStreamInfo? audioStream;

  @override
  bool get isMerged => videoStream != null && audioStream != null;

  @override
  int? get videoHeight {
    if (videoStream != null) return videoStream!.videoResolution.height;
    final single = singleStream;
    if (single is MuxedStreamInfo) return single.videoResolution.height;
    return null;
  }

  @override
  int get estimatedSizeBytes {
    if (videoStream != null && audioStream != null) {
      return videoStream!.size.totalBytes + audioStream!.size.totalBytes;
    }
    return singleStream?.size.totalBytes ?? 0;
  }
}
