import '../../../../core/utils/video_link_parser.dart';
import '../../domain/entities/download_cancel_token.dart';
import '../../domain/entities/download_progress.dart';
import '../../domain/entities/download_stream.dart';
import '../../domain/entities/video_info.dart';
import '../../domain/repositories/video_repository.dart';
import '../models/tiktok_download_stream.dart';

/// Routes fetch/download calls to the YouTube or TikTok repository based on
/// the pasted URL.
class CompositeVideoRepository implements VideoRepository {
  CompositeVideoRepository({
    required VideoRepository youtube,
    required VideoRepository tiktok,
  })  : _youtube = youtube,
        _tiktok = tiktok;

  final VideoRepository _youtube;
  final VideoRepository _tiktok;

  VideoRepository _for(String urlOrId) {
    final platform = VideoLinkParser.detect(urlOrId);
    return switch (platform) {
      VideoSourcePlatform.tiktok => _tiktok,
      VideoSourcePlatform.youtube => _youtube,
      null => throw ArgumentError(
          'Unsupported link. Paste a YouTube or TikTok video URL.',
        ),
    };
  }

  @override
  Future<VideoInfo> getVideoInfo(String urlOrId) =>
      _for(urlOrId).getVideoInfo(urlOrId);

  @override
  Future<List<DownloadStream>> getDownloadStreams(String urlOrId) =>
      _for(urlOrId).getDownloadStreams(urlOrId);

  @override
  Future<String> downloadStream({
    required DownloadStream stream,
    required String fileName,
    required String fileSuffix,
    void Function(DownloadProgress progress)? onProgress,
    DownloadCancelToken? cancelToken,
  }) {
    final repo = stream is TiktokDownloadStream ? _tiktok : _youtube;
    return repo.downloadStream(
      stream: stream,
      fileName: fileName,
      fileSuffix: fileSuffix,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }

  @override
  void dispose() {
    _youtube.dispose();
    _tiktok.dispose();
  }
}
