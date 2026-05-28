import '../../domain/entities/download_stream.dart';

/// Facebook direct-URL download option. Mirrors TiktokDownloadStream: a
/// pre-resolved CDN URL the downloader fetches via dio.
class FacebookDownloadStream implements DownloadStream {
  FacebookDownloadStream({
    required this.id,
    required this.label,
    required this.directUrl,
    required this.height,
    required this.isAudio,
  });

  @override
  final String id;
  @override
  final String label;
  final String directUrl;
  final int height;
  final bool isAudio;

  @override
  String get extension => isAudio ? 'mp3' : 'mp4';

  @override
  bool get isVideo => !isAudio;

  @override
  bool get isMerged => false;

  @override
  int? get videoHeight => isAudio ? null : height;

  // Facebook's CDN doesn't include a Content-Length in its og:video / playable
  // URL JSON, so we don't pre-compute a size — dio fills it in from the
  // download response headers when it arrives.
  @override
  int get estimatedSizeBytes => 0;
}
