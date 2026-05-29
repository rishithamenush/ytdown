import '../../../../core/utils/video_link_parser.dart';
import '../entities/download_stream.dart';
import '../entities/video_info.dart';
import '../repositories/video_repository.dart';

/// Validates a pasted URL and fetches its metadata + downloadable streams in
/// a single repository round-trip.
class FetchVideoInfo {
  const FetchVideoInfo(this._repository);

  final VideoRepository _repository;

  Future<FetchVideoResult> call(String urlOrId) async {
    final trimmed = urlOrId.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError(
        'Paste a video link or a direct file URL to download',
      );
    }
    if (VideoLinkParser.detect(trimmed) == null) {
      throw ArgumentError(
        'Unsupported link. Paste a YouTube, TikTok, or Facebook URL, '
        'or a direct file link.',
      );
    }
    final bundle = await _repository.getVideoBundle(trimmed);
    if (bundle.streams.isEmpty) {
      throw StateError('No downloadable streams found for this video');
    }
    return FetchVideoResult(info: bundle.info, streams: bundle.streams);
  }
}

class FetchVideoResult {
  const FetchVideoResult({required this.info, required this.streams});

  final VideoInfo info;
  final List<DownloadStream> streams;
}
