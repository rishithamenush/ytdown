import 'download_cancel_token.dart';
import 'download_progress.dart';

enum DownloadTaskStatus { downloading, completed, cancelled, failed }

/// In-flight (or finished) download tracked by the UI. Mutable — the
/// HomeNotifier mutates progress/status as bytes arrive and publishes
/// new state snapshots to listeners.
class DownloadTask {
  DownloadTask({
    required this.id,
    required this.videoId,
    required this.videoTitle,
    required this.qualityLabel,
    required this.streamId,
    required this.isVideo,
    required this.cancelToken,
  });

  final String id;
  final String videoId;
  final String videoTitle;
  final String qualityLabel;
  final String streamId;
  final bool isVideo;
  final DownloadCancelToken cancelToken;

  DownloadTaskStatus status = DownloadTaskStatus.downloading;
  DownloadProgress progress = const DownloadProgress.initial();
  String? savedPath;
  String? errorMessage;

  bool get isActive => status == DownloadTaskStatus.downloading;
}
