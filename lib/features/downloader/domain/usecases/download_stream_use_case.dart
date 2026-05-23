import '../entities/download_cancel_token.dart';
import '../entities/download_progress.dart';
import '../entities/download_stream.dart';
import '../repositories/video_repository.dart';

/// Wraps [VideoRepository.downloadStream] so the presentation layer talks to
/// a use case instead of the repository directly. Today it's a thin pass-
/// through; the seam exists so we can add cross-cutting concerns later
/// (analytics, retry policy, queue limits) without touching every caller.
class DownloadStreamUseCase {
  const DownloadStreamUseCase(this._repository);

  final VideoRepository _repository;

  Future<String> call({
    required DownloadStream stream,
    required String fileName,
    required String fileSuffix,
    void Function(DownloadProgress progress)? onProgress,
    DownloadCancelToken? cancelToken,
  }) {
    return _repository.downloadStream(
      stream: stream,
      fileName: fileName,
      fileSuffix: fileSuffix,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }
}
