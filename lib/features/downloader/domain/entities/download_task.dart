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

  /// Serializes finished-state fields for persistence. Active progress and
  /// the cancel token are intentionally dropped — restored tasks are never
  /// resumed; they appear in the list as already-finished history rows.
  Map<String, dynamic> toJson() => {
        'id': id,
        'videoId': videoId,
        'videoTitle': videoTitle,
        'qualityLabel': qualityLabel,
        'streamId': streamId,
        'isVideo': isVideo,
        'status': status.name,
        'savedPath': savedPath,
        'errorMessage': errorMessage,
      };

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    final task = DownloadTask(
      id: json['id'] as String,
      videoId: json['videoId'] as String? ?? '',
      videoTitle: json['videoTitle'] as String? ?? '',
      qualityLabel: json['qualityLabel'] as String? ?? '',
      streamId: json['streamId'] as String? ?? '',
      isVideo: json['isVideo'] as bool? ?? true,
      cancelToken: DownloadCancelToken(),
    );
    final statusName = json['status'] as String?;
    task.status = DownloadTaskStatus.values.firstWhere(
      (s) => s.name == statusName,
      orElse: () => DownloadTaskStatus.completed,
    );
    // Restored tasks must never be "downloading" — if the app died mid-
    // download we surface it as cancelled rather than spinning forever.
    if (task.status == DownloadTaskStatus.downloading) {
      task.status = DownloadTaskStatus.cancelled;
    }
    task.savedPath = json['savedPath'] as String?;
    task.errorMessage = json['errorMessage'] as String?;
    return task;
  }

  /// User-facing folder hint shown after a successful save.
  String get savedLocationLabel {
    final path = savedPath;
    if (path != null) {
      if (path.contains('Music')) return 'Music/Vidoory';
      if (path.contains('Movies')) return 'Movies/Vidoory';
      if (path.contains('Download')) return 'Download/Vidoory';
      if (path.contains('Vidoory')) return 'Files · Vidoory';
    }
    return isVideo ? 'Movies/Vidoory' : 'Download/Vidoory';
  }
}
