import '../../../../core/utils/video_link_parser.dart';
import '../entities/download_stream.dart';
import '../entities/video_info.dart';
import '../repositories/video_repository.dart';

/// Bundles the two repository calls the home page makes back-to-back when
/// the user submits a URL: fetch metadata + list downloadable streams.
class FetchVideoInfo {
  const FetchVideoInfo(this._repository);

  final VideoRepository _repository;

  Future<FetchVideoResult> call(String urlOrId) async {
    final trimmed = urlOrId.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Paste a YouTube, TikTok, or Facebook video link');
    }
    if (VideoLinkParser.detect(trimmed) == null) {
      throw ArgumentError(
        'Unsupported link. Paste a YouTube, TikTok, or Facebook URL.',
      );
    }
    final info = await _repository.getVideoInfo(trimmed);
    final streams = await _repository.getDownloadStreams(trimmed);
    if (streams.isEmpty) {
      throw StateError('No downloadable streams found for this video');
    }
    return FetchVideoResult(info: info, streams: streams);
  }
}

class FetchVideoResult {
  const FetchVideoResult({required this.info, required this.streams});

  final VideoInfo info;
  final List<DownloadStream> streams;
}
