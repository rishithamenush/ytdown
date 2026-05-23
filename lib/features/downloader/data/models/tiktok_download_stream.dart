import '../../domain/entities/download_stream.dart';

/// TikTok direct-URL download option fetched via the TikWM API.
/// Supports no-watermark video, watermarked video, and audio-only variants.
class TiktokDownloadStream implements DownloadStream {
  TiktokDownloadStream({
    required this.id,
    required this.label,
    required this.directUrl,
    required this.estimatedBytes,
    required this.height,
    required this.isAudio,
    required this.noWatermark,
  });

  @override
  final String id;
  @override
  final String label;
  final String directUrl;
  final int estimatedBytes;
  final int height;
  final bool isAudio;
  final bool noWatermark;

  @override
  String get extension => isAudio ? 'mp3' : 'mp4';

  @override
  bool get isVideo => !isAudio;

  @override
  bool get isMerged => false;

  @override
  int? get videoHeight => isAudio ? null : height;

  @override
  int get estimatedSizeBytes => estimatedBytes;
}
