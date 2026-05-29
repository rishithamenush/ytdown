import '../../domain/entities/download_stream.dart';

/// What kind of file sits behind a direct link — drives both the save
/// location (Movies / Music / Download) and how the tile is rendered.
enum DirectFileKind { video, audio, other }

/// A plain file at a direct HTTP(S) URL (not a video-platform stream). The
/// downloader fetches [directUrl] as-is with the segmented engine.
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

  /// When true, complete [DirectLinkBrowserSheet] before downloading.
  final bool requiresBrowserSession;

  @override
  String get extension => fileExtension;

  // Audio renders as an audio tile; video and other files share the generic
  // "file" tile (signalled by isVideo == true && videoHeight == null). Storage
  // routing reads [kind] directly, so this mapping only affects presentation.
  @override
  bool get isVideo => kind != DirectFileKind.audio;

  @override
  bool get isMerged => false;

  @override
  int? get videoHeight => null;
}
