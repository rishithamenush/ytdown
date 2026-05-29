import '../entities/download_cancel_token.dart';
import '../entities/download_progress.dart';
import '../entities/download_stream.dart';
import '../repositories/video_repository.dart';

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
