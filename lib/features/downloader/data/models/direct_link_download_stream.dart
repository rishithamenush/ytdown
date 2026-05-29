import '../../domain/entities/download_stream.dart';

enum DirectFileKind { video, audio, other }

class DirectLinkDownloadStream implements DownloadStream {
  DirectLinkDownloadStream({
    required this.id,
    required this.label,
    required this.directUrl,
    required this.fileExtension,
    required this.kind,
    required this.estimatedSizeBytes,
    this.requiresBrowserSession = false,
  });

  @override
  final String id;
  @override
  final String label;
  final String directUrl;
  final String fileExtension;
  final DirectFileKind kind;
  @override
  final int estimatedSizeBytes;

  final bool requiresBrowserSession;

  @override
  String get extension => fileExtension;

  @override
  bool get isVideo => kind != DirectFileKind.audio;

  @override
  bool get isMerged => false;

  @override
  int? get videoHeight => null;
}
