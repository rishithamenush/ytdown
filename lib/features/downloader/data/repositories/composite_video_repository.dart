import '../../../../core/utils/video_link_parser.dart';
import '../../domain/entities/download_cancel_token.dart';
import '../../domain/entities/download_progress.dart';
import '../../domain/entities/download_stream.dart';
import '../../domain/entities/video_info.dart';
import '../../domain/repositories/video_repository.dart';
import '../models/facebook_download_stream.dart';
import '../models/tiktok_download_stream.dart';

/// Routes fetch/download calls to the YouTube, TikTok, or Facebook repository
/// based on the pasted URL.
class CompositeVideoRepository implements VideoRepository {
  CompositeVideoRepository({
    required VideoRepository youtube,
    required VideoRepository tiktok,
    required VideoRepository facebook,
  })  : _youtube = youtube,
        _tiktok = tiktok,
        _facebook = facebook;

  final VideoRepository _youtube;
  final VideoRepository _tiktok;
  final VideoRepository _facebook;

  VideoRepository _for(String urlOrId) {
    final platform = VideoLinkParser.detect(urlOrId);
    return switch (platform) {
      VideoSourcePlatform.tiktok => _tiktok,
      VideoSourcePlatform.youtube => _youtube,
      VideoSourcePlatform.facebook => _facebook,
      null => throw ArgumentError(
          'Unsupported link. Paste a YouTube, TikTok, or Facebook video URL.',
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
    final repo = switch (stream) {
      TiktokDownloadStream _ => _tiktok,
      FacebookDownloadStream _ => _facebook,
      _ => _youtube,
    };
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
    _facebook.dispose();
  }
}
