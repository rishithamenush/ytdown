import '../../domain/entities/download_stream.dart';

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

  @override
  int get estimatedSizeBytes => 0;
}
