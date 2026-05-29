import '../entities/download_cancel_token.dart';
import '../entities/download_progress.dart';
import '../entities/download_stream.dart';
import '../entities/video_info.dart';

abstract class VideoRepository {
  Future<VideoBundle> getVideoBundle(String urlOrId);

  Future<String> downloadStream({
    required DownloadStream stream,
    required String fileName,
    required String fileSuffix,
    void Function(DownloadProgress progress)? onProgress,
    DownloadCancelToken? cancelToken,
  });

  void dispose();
}

class VideoBundle {
  const VideoBundle({required this.info, required this.streams});

  final VideoInfo info;
  final List<DownloadStream> streams;
}
